# Patient timeline sources (POR-03)

The physician portal's Timeline tab calls `public.patient_timeline(patient, before, limit)`.
That function unions every enabled row of `public.timeline_sources`, newest first. Adding data to
the timeline means adding a source. You never edit the dispatcher.

## Contract

A source is a function:

```sql
public.timeline_source_<key>(p_patient_id uuid) returns setof public.timeline_event
```

`public.timeline_event` is `(occurred_at timestamptz, source text, event_type text, title text,
status text, ref_id uuid, detail jsonb)`.

- **SECURITY INVOKER.** A trigger on `timeline_sources` refuses SECURITY DEFINER functions and
  functions of the wrong shape. Because the source runs with the caller's rights, RLS on the
  underlying table decides what it returns. A source can't leak another clinic's rows, even
  without its own org check. If the caller can't read the table, the source returns nothing.
- **Whitelisted `detail`.** Use only explicit keys, never `to_jsonb(row)`. Include no free text
  and never a dose. The portal mapper (`lib/patientRecordApi.ts`) also drops unknown keys.
- `EXECUTE` is granted to `authenticated`, plus a line in the allowlist in
  `supabase/tests/747_tc040_function_execute_allowlist.sql`.
- The source's table needs a staff `SELECT` policy (physician / care_coordinator / read_only,
  `org_id = current_org_id()`, `has_aal2()`).

## Adding a source (one migration)

```sql
create function public.timeline_source_wearables(p_patient_id uuid)
returns setof public.timeline_event
language sql stable security invoker
set search_path = pg_catalog, public
as $$
  select w.day::timestamptz, 'wearables', 'wearable_day', 'Wearable summary', null::text, w.id,
         jsonb_build_object('steps', w.steps)
  from public.wearable_daily w
  where w.patient_id = p_patient_id;
$$;
grant execute on function public.timeline_source_wearables(uuid) to authenticated;
insert into public.timeline_sources (source_key, fn, label)
values ('wearables', 'public.timeline_source_wearables(uuid)', 'Wearables');
```

Then, in the portal, add the key to `SOURCE_META` in `lib/timelineFormat.ts`, plus any event
wording in `eventTitle` / `eventSummary`. Until you do, the event still renders with its `title`
and the label "Other".

## Shipped sources

| key | table(s) | events |
|---|---|---|
| `labs` | `lab_reports`, `lab_results` | one per report (identity-held reports excluded), with effective (approved-range) status per value |
| `treatment` | `patient_treatments` | treatment started (name / status / source; no dose) |
| `program` | `patient_roster_meta` | program started |
| `visits` | `patient_visits` (POR-04) | visit recorded |

These are pending, from parallel branches: `wearable_daily`, `food_logs`, companion escalations.

## Paging

`p_before` is exclusive keyset paging on `occurred_at`. Events that share the exact boundary
timestamp with the last row of a full page (200 rows) can be skipped on "Show older events". This
is a known limitation; the fix is a `(occurred_at, source, ref_id)` cursor.
