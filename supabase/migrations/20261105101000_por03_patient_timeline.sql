-- POR-03: one chronological timeline per patient, built on a registry of
-- event sources so new data (wearable_daily, food_logs, companion
-- escalations, ...) plugs in without touching the dispatcher.
--
-- Contract for a timeline source (see docs/architecture/timeline-sources.md):
--   * a function public.timeline_source_<key>(p_patient_id uuid)
--       returns setof public.timeline_event
--     that is SECURITY INVOKER (the trigger below refuses a definer function),
--     so the caller's RLS decides what it can return - a source never needs
--     its own org check to be safe, and a source over a table the caller
--     cannot read simply returns nothing;
--   * EXECUTE granted to authenticated (and an allowlist line in test 747);
--   * one row in public.timeline_sources.
-- patient_timeline() unions every enabled source, newest first, keyset-paged
-- on occurred_at. Sources shipped here: labs, treatment, program. POR-04 adds
-- 'visits'. wearable_daily / food_logs / companion escalations are not on main
-- yet; their branches add a source the same way.
-- Tests: supabase/tests/771_por03_patient_timeline.sql.

create type public.timeline_event as (
  occurred_at timestamptz,
  source text,
  event_type text,
  title text,
  status text,
  ref_id uuid,
  detail jsonb
);

create table public.timeline_sources (
  source_key text primary key check (source_key ~ '^[a-z0-9_]{1,40}$'),
  fn regprocedure not null unique,
  label text not null,
  enabled boolean not null default true,
  added_at timestamptz not null default now()
);

alter table public.timeline_sources enable row level security;
alter table public.timeline_sources force row level security;
revoke insert, update, delete on public.timeline_sources from anon, authenticated;
-- Configuration, not patient data: any signed-in session may read it (the
-- invoker dispatcher must, to know what to union).
grant select on public.timeline_sources to authenticated;
create policy timeline_sources_read on public.timeline_sources
  for select
  to authenticated
  using (true);

-- A registered source must have the exact contract shape and be
-- SECURITY INVOKER, so RLS always applies to what it returns.
create function public._enforce_timeline_source_contract()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_proc pg_proc;
begin
  select * into v_proc from pg_proc where oid = NEW.fn;
  if v_proc.prosecdef then
    raise exception 'timeline source % must be SECURITY INVOKER', NEW.fn using errcode = '42501';
  end if;
  if v_proc.prorettype <> 'public.timeline_event'::regtype or not v_proc.proretset
     or pg_catalog.oidvectortypes(v_proc.proargtypes) <> 'uuid' then
    raise exception 'timeline source % must be (uuid) returns setof public.timeline_event', NEW.fn
      using errcode = '22023';
  end if;
  return NEW;
end;
$$;

create trigger trg_timeline_source_contract
  before insert or update on public.timeline_sources
  for each row execute function public._enforce_timeline_source_contract();

revoke all on function public._enforce_timeline_source_contract() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Source: labs. One event per lab report (identity-held reports excluded),
-- at its latest result time; results carry the effective (approved-set)
-- status and range. A report with no extracted values yet is still an event.
-- ---------------------------------------------------------------------------

create function public.timeline_source_labs(p_patient_id uuid)
returns setof public.timeline_event
language sql
stable
security invoker
set search_path = pg_catalog, public
as $$
  select
    coalesce(max(x.taken_at), r.created_at),
    'labs',
    case when count(x.analyte_key) = 0 then 'lab_report_received' else 'lab_report' end,
    r.report_type,
    case
      when bool_or(x.status = 'needs_review') then 'needs_review'
      when bool_or(x.status = 'outside_range') then 'outside_range'
      when count(x.analyte_key) = 0 then 'pending'
      else 'within_range'
    end,
    r.id,
    jsonb_build_object(
      'report_type', r.report_type,
      'result_count', count(x.analyte_key),
      'outside_count', count(*) filter (where x.status = 'outside_range'),
      'needs_review_count', count(*) filter (where x.status = 'needs_review'),
      'results', coalesce(
        jsonb_agg(jsonb_build_object(
          'analyte_key', x.analyte_key,
          'analyte_label', x.analyte_label,
          'value', x.value,
          'original_value', x.original_value,
          'unit', x.unit,
          'status', x.status,
          'range_low', x.range_low,
          'range_high', x.range_high,
          'range_source', x.range_source
        ) order by x.analyte_label) filter (where x.analyte_key is not null),
        '[]'::jsonb)
    )
  from public.lab_reports r
  left join lateral (
    select
      lr.analyte_key, lr.analyte_label, lr.value, lr.original_value, lr.unit, lr.taken_at,
      public.lab_effective_status(lr.status, lr.is_unmapped, lr.value, er.range_set_version is not null, er.range_low, er.range_high) as status,
      case when er.range_set_version is not null then er.range_low else lr.range_low end as range_low,
      case when er.range_set_version is not null then er.range_high else lr.range_high end as range_high,
      case
        when er.range_set_version is not null then 'approved'
        when lr.range_low is not null or lr.range_high is not null then 'default'
        else 'none'
      end as range_source
    from public.lab_results lr
    left join lateral public.lab_effective_range(lr.org_id, p_patient_id, lr.analyte_key, lr.unit) er on true
    where lr.lab_report_id = r.id and lr.patient_id = p_patient_id
  ) x on true
  where r.patient_id = p_patient_id
    and not public.lab_report_held(r.id)
  group by r.id, r.report_type, r.created_at;
$$;

-- ---------------------------------------------------------------------------
-- Source: treatment. Explicit columns only - never a dose (there is none).
-- ---------------------------------------------------------------------------

create function public.timeline_source_treatment(p_patient_id uuid)
returns setof public.timeline_event
language sql
stable
security invoker
set search_path = pg_catalog, public
as $$
  select
    coalesce(t.started_on::timestamptz, t.created_at),
    'treatment',
    'treatment_started',
    t.name,
    t.status,
    t.id,
    jsonb_build_object('name', t.name, 'status', t.status, 'source', t.source, 'started_on', t.started_on)
  from public.patient_treatments t
  where t.patient_id = p_patient_id;
$$;

-- ---------------------------------------------------------------------------
-- Source: program start (roster meta).
-- ---------------------------------------------------------------------------

create function public.timeline_source_program(p_patient_id uuid)
returns setof public.timeline_event
language sql
stable
security invoker
set search_path = pg_catalog, public
as $$
  select
    m.program_started_on::timestamptz,
    'program',
    'program_started',
    'Program started',
    null::text,
    m.patient_id,
    '{}'::jsonb
  from public.patient_roster_meta m
  where m.patient_id = p_patient_id
    and m.program_started_on is not null;
$$;

grant execute on function public.timeline_source_labs(uuid) to authenticated;
grant execute on function public.timeline_source_treatment(uuid) to authenticated;
grant execute on function public.timeline_source_program(uuid) to authenticated;

insert into public.timeline_sources (source_key, fn, label) values
  ('labs', 'public.timeline_source_labs(uuid)', 'Labs'),
  ('treatment', 'public.timeline_source_treatment(uuid)', 'Treatment'),
  ('program', 'public.timeline_source_program(uuid)', 'Program');

-- ---------------------------------------------------------------------------
-- Dispatcher. SECURITY INVOKER; same visibility contract as
-- open_patient_detail (clinical staff, aal2, own clinic) - anything else gets
-- an empty timeline, never an error that says the patient exists.
-- Keyset paging: pass the last row's occurred_at as p_before.
-- ---------------------------------------------------------------------------

create function public.patient_timeline(
  p_patient_id uuid,
  p_before timestamptz default null,
  p_limit int default 100
)
returns setof public.timeline_event
language plpgsql
stable
security invoker
set search_path = pg_catalog, public
as $$
declare
  v_sql text;
begin
  if auth.uid() is null
     or not public.has_aal2()
     or coalesce(public.current_role()::text, '') not in ('physician', 'care_coordinator', 'read_only')
     or not exists (
       select 1 from public.patients p
        where p.id = p_patient_id and p.org_id = public.current_org_id()
     ) then
    return;
  end if;

  select string_agg(format('select * from %I.%I($1)', n.nspname, pr.proname), ' union all ' order by s.source_key)
    into v_sql
    from public.timeline_sources s
    join pg_proc pr on pr.oid = s.fn
    join pg_namespace n on n.oid = pr.pronamespace
   where s.enabled;

  if v_sql is null then
    return;
  end if;

  return query execute
    'select * from (' || v_sql || ') e'
    || ' where e.occurred_at is not null and ($2 is null or e.occurred_at < $2)'
    || ' order by e.occurred_at desc, e.source, e.ref_id'
    || ' limit $3'
    using p_patient_id, p_before, least(greatest(coalesce(p_limit, 100), 1), 500);
end;
$$;

revoke all on function public.patient_timeline(uuid, timestamptz, int) from public, anon;
grant execute on function public.patient_timeline(uuid, timestamptz, int) to authenticated;
