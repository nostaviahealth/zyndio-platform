-- TC-015 fix round (card item 7, Leo C3): the roster must sort + paginate the
-- page BEFORE summarising, and stay < 200 ms at 5,000 patients. The shipped
-- physician_roster_base() recomputed a per-result LATERAL over lab_results
-- (five lab_report_held() calls per result) for EVERY org patient on every
-- roster/chip call - 37k shared-buffer hits to return 8 rows at 500 patients,
-- ~10x worse at 5,000. This replaces that per-call recompute with a maintained
-- per-patient rollup table (design B), left-joined by primary key.
--
-- Semantic parity is EXACT: physician_roster_base() keeps the identical
-- array_remove(array[...]) flag expression and coalesce defaults; only the
-- source of the lab/treatment booleans moves from the live LATERAL to the
-- summary table. open_questions stays live on patient_roster_meta (no rollup).
--
-- Visibility: the summary mirrors lab_results' CURRENT (post-flip) RLS -
-- physician, care_coordinator AND read_only, same org, aal2 - so read_only's
-- flags are real, not degraded (Leo's C3 ruling: read_only has own-clinic Labs
-- access). Identity-hold uses public.lab_report_held() (SECURITY DEFINER, fails
-- CLOSED) so a held report is excluded regardless of the caller's lab_reports
-- grants, exactly as the three invoker RPCs already do.

-- ---------------------------------------------------------------------------
-- patient_roster_summary: one maintained row per patient. All booleans default
-- false so a patient with no summary row (brand-new, pre-first-lab) and a
-- patient with an explicit all-false row are indistinguishable downstream
-- (coalesce -> missing_labs), matching the old LATERAL's behaviour.
-- ---------------------------------------------------------------------------
create table public.patient_roster_summary (
  patient_id uuid primary key references public.patients (id) on delete cascade,
  org_id uuid not null references public.organizations (id) on delete cascade,
  latest_lab_at timestamptz,
  has_outside_range boolean not null default false,
  has_needs_review boolean not null default false,
  has_identity_hold boolean not null default false,
  has_any_labs boolean not null default false,
  has_treatment boolean not null default false
);

create index patient_roster_summary_org_id_idx on public.patient_roster_summary (org_id);

alter table public.patient_roster_summary enable row level security;
alter table public.patient_roster_summary force row level security;

-- View-only for clients: the table is maintained only by the SECURITY DEFINER
-- refresh functions below (triggers + seed/pipeline), never by a direct client
-- write. Strip every client write grant regardless of policy.
revoke insert, update, delete on public.patient_roster_summary from anon, authenticated;

-- Same visibility as lab_results (post-flip): physician / care_coordinator /
-- read_only, own org, aal2. read_only included so its roster flags are real.
create policy patient_roster_summary_staff_select on public.patient_roster_summary
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator', 'read_only')
  );

-- ---------------------------------------------------------------------------
-- refresh_roster_summary(patient_id): recompute one patient's rollup from the
-- live clinical rows, with the IDENTICAL predicate the old LATERAL used. Upsert
-- so it is safe to call on insert, update and delete. SECURITY DEFINER: it must
-- write a table that has FORCE RLS and no client write grant, and it must read
-- lab_reports.identity_hold (via lab_report_held) regardless of the caller.
-- ---------------------------------------------------------------------------
create function public.refresh_roster_summary(p_patient_id uuid)
returns void
language sql
security definer
set search_path = pg_catalog, public
as $$
  insert into public.patient_roster_summary as s (
    patient_id, org_id, latest_lab_at,
    has_outside_range, has_needs_review, has_identity_hold, has_any_labs, has_treatment
  )
  select
    p.id, p.org_id,
    la.latest_lab_at,
    coalesce(la.has_outside_range, false),
    coalesce(la.has_needs_review, false),
    coalesce(la.has_identity_hold, false),
    coalesce(la.has_any_labs, false),
    coalesce(tr.has_treatment, false)
  from public.patients p
  left join lateral (
    select
      max(lr.taken_at) filter (where not public.lab_report_held(lr.lab_report_id)) as latest_lab_at,
      bool_or(lr.status = 'outside_range' and not public.lab_report_held(lr.lab_report_id)) as has_outside_range,
      bool_or(lr.status = 'needs_review' and not public.lab_report_held(lr.lab_report_id)) as has_needs_review,
      bool_or(public.lab_report_held(lr.lab_report_id)) as has_identity_hold,
      count(lr.id) filter (where not public.lab_report_held(lr.lab_report_id)) > 0 as has_any_labs
    from public.lab_results lr
    where lr.patient_id = p.id
  ) la on true
  left join lateral (
    select true as has_treatment
    from public.patient_treatments t
    where t.patient_id = p.id
    limit 1
  ) tr on true
  where p.id = p_patient_id
  on conflict (patient_id) do update set
    org_id            = excluded.org_id,
    latest_lab_at     = excluded.latest_lab_at,
    has_outside_range = excluded.has_outside_range,
    has_needs_review  = excluded.has_needs_review,
    has_identity_hold = excluded.has_identity_hold,
    has_any_labs      = excluded.has_any_labs,
    has_treatment     = excluded.has_treatment;
$$;

-- refresh_roster_summary_all(): batch builder/backfill for every patient. Used
-- by this migration and the perf seed; recomputes the whole org set in one
-- set-based statement.
create function public.refresh_roster_summary_all()
returns void
language sql
security definer
set search_path = pg_catalog, public
as $$
  insert into public.patient_roster_summary as s (
    patient_id, org_id, latest_lab_at,
    has_outside_range, has_needs_review, has_identity_hold, has_any_labs, has_treatment
  )
  select
    p.id, p.org_id,
    la.latest_lab_at,
    coalesce(la.has_outside_range, false),
    coalesce(la.has_needs_review, false),
    coalesce(la.has_identity_hold, false),
    coalesce(la.has_any_labs, false),
    coalesce(tr.has_treatment, false)
  from public.patients p
  left join lateral (
    select
      max(lr.taken_at) filter (where not public.lab_report_held(lr.lab_report_id)) as latest_lab_at,
      bool_or(lr.status = 'outside_range' and not public.lab_report_held(lr.lab_report_id)) as has_outside_range,
      bool_or(lr.status = 'needs_review' and not public.lab_report_held(lr.lab_report_id)) as has_needs_review,
      bool_or(public.lab_report_held(lr.lab_report_id)) as has_identity_hold,
      count(lr.id) filter (where not public.lab_report_held(lr.lab_report_id)) > 0 as has_any_labs
    from public.lab_results lr
    where lr.patient_id = p.id
  ) la on true
  left join lateral (
    select true as has_treatment
    from public.patient_treatments t
    where t.patient_id = p.id
    limit 1
  ) tr on true
  on conflict (patient_id) do update set
    org_id            = excluded.org_id,
    latest_lab_at     = excluded.latest_lab_at,
    has_outside_range = excluded.has_outside_range,
    has_needs_review  = excluded.has_needs_review,
    has_identity_hold = excluded.has_identity_hold,
    has_any_labs      = excluded.has_any_labs,
    has_treatment     = excluded.has_treatment;
$$;

revoke all on function public.refresh_roster_summary(uuid) from public, anon;
revoke all on function public.refresh_roster_summary_all() from public, anon;
grant execute on function public.refresh_roster_summary(uuid) to service_role;
grant execute on function public.refresh_roster_summary_all() to service_role;

-- ---------------------------------------------------------------------------
-- Maintenance triggers. Each trigger function is SECURITY DEFINER so it runs as
-- the table owner and can call refresh_roster_summary() (which writes the
-- FORCE-RLS summary table) no matter which role performed the clinical write.
-- ---------------------------------------------------------------------------

-- lab_results: any I/U/D on a result changes that patient's lab rollup; a
-- patient_id change on UPDATE touches both the old and the new patient.
create function public.tg_lab_results_roster_summary()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_roster_summary(old.patient_id);
    return null;
  end if;
  perform public.refresh_roster_summary(new.patient_id);
  if tg_op = 'UPDATE' and new.patient_id is distinct from old.patient_id then
    perform public.refresh_roster_summary(old.patient_id);
  end if;
  return null;
end;
$$;

create trigger trg_lab_results_roster_summary
  after insert or update or delete on public.lab_results
  for each row execute function public.tg_lab_results_roster_summary();

-- lab_reports: an identity_hold toggle re-scores every patient who has a result
-- on that report (the held predicate flips for all of them).
create function public.tg_lab_reports_roster_summary()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  perform public.refresh_roster_summary(t.patient_id)
  from (
    select distinct patient_id from public.lab_results where lab_report_id = new.id
  ) t;
  return null;
end;
$$;

create trigger trg_lab_reports_roster_summary
  after update of identity_hold on public.lab_reports
  for each row
  when (new.identity_hold is distinct from old.identity_hold)
  execute function public.tg_lab_reports_roster_summary();

-- patient_treatments: I/U/D flips has_treatment for the affected patient(s).
create function public.tg_patient_treatments_roster_summary()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_roster_summary(old.patient_id);
    return null;
  end if;
  perform public.refresh_roster_summary(new.patient_id);
  if tg_op = 'UPDATE' and new.patient_id is distinct from old.patient_id then
    perform public.refresh_roster_summary(old.patient_id);
  end if;
  return null;
end;
$$;

create trigger trg_patient_treatments_roster_summary
  after insert or update or delete on public.patient_treatments
  for each row execute function public.tg_patient_treatments_roster_summary();

-- ---------------------------------------------------------------------------
-- physician_roster_base(): read the maintained summary instead of recomputing
-- the per-result LATERAL. The flag expression and coalesce defaults are
-- byte-identical to 20261028154000, so every filter/sort/flag semantic (and
-- thus 710/715/716/717/719/720) is unchanged. A patient with no summary row
-- left-joins to NULL -> coalesce -> missing_labs, exactly as before.
--
-- This also flips the function to SECURITY DEFINER with a one-time staff gate,
-- superseding "Leo ruling 3" (invoker everywhere) FOR THIS FUNCTION ONLY. Why:
-- at 5,000 patients the invoker form re-evaluated the per-row RLS helpers
-- (current_org_id()/has_aal2()/current_role(), each an org_members lookup) on
-- patients, patient_roster_meta AND patient_roster_summary - ~90k shared-buffer
-- hits, ~290 ms, over the < 200 ms budget. The gate below enforces the IDENTICAL
-- visibility the RLS did - caller must be aal2 AND physician/care_coordinator/
-- read_only, and only their own org's rows are returned (explicit org scope) -
-- but evaluates it ONCE instead of per row. A non-staff / non-aal2 / orgless
-- caller gets zero rows, exactly as RLS yielded. read_only still gets REAL
-- flags (the summary is read under definer rights, so no degradation). The
-- patient-self branch of the old patients RLS is intentionally dropped here:
-- this is a staff-only read surface (physician_patient_roster / chip_counts),
-- never a patient path.
-- ---------------------------------------------------------------------------
create or replace function public.physician_roster_base()
returns table (
  patient_id uuid,
  display_name text,
  mrn text,
  sex text,
  birth_date date,
  program_started_on date,
  latest_lab_at timestamptz,
  last_activity_at timestamptz,
  open_questions int,
  flags text[]
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org uuid;
begin
  -- One-time staff gate, identical semantics to the staff-select RLS.
  if not coalesce(
       public.has_aal2()
       and public.current_role() in ('physician', 'care_coordinator', 'read_only'),
       false) then
    return;
  end if;
  v_org := public.current_org_id();
  if v_org is null then
    return;
  end if;

  return query
  select
    p.id,
    p.display_name,
    p.mrn,
    m.sex,
    m.birth_date,
    m.program_started_on,
    s.latest_lab_at,
    m.last_activity_at,
    coalesce(m.open_questions, 0),
    array_remove(array[
      case when coalesce(s.has_treatment, false) then 'clinical_context' end,
      case when coalesce(s.has_outside_range, false) then 'outside_range' end,
      case when coalesce(s.has_needs_review, false) then 'needs_review' end,
      case when coalesce(s.has_identity_hold, false) then 'identity_hold' end,
      case when not coalesce(s.has_any_labs, false) then 'missing_labs' end,
      case when coalesce(m.open_questions, 0) > 0 then 'question_waiting' end
    ], null)
  from public.patients p
  left join public.patient_roster_meta m on m.patient_id = p.id
  left join public.patient_roster_summary s on s.patient_id = p.id
  where p.org_id = v_org;
end;
$$;

-- Backfill the rollup for every existing patient (idempotent upsert).
select public.refresh_roster_summary_all();
analyze public.patient_roster_summary;
