-- TC-021 item 5 (Ava #11; ruling Henry, 29 Oct): the roster's "Outside range"
-- flag means "the LATEST result for any marker is outside its range". It is now
-- computed per marker from the same rows the patient-detail badges use
-- (public.patient_latest_results: latest per analyte_key, identity-held reports
-- and corrected originals excluded), instead of bool_or over every result ever
-- recorded (20261028160000 L88 / L137, carried into 20261028171000). A patient
-- with an older outside-range HbA1c and a latest 5.4% within range is no longer
-- flagged.
--
-- Only the two refresh functions change (write-time maintenance); the roster
-- read path (physician_roster_base -> patient_roster_summary by primary key) is
-- untouched, so the 200 ms at 5,000 patients budget is unaffected. Ties on
-- taken_at break on id, here and in patient_latest_results, so both always pick
-- the same row. Every other column is byte-identical to 20261028171000; grants
-- are preserved by create or replace. The last statement backfills the rollup.
-- Tests: supabase/tests/724_tc021_roster_flag_latest_per_marker.sql (+ 720 parity).

create or replace function public.refresh_roster_summary(p_patient_id uuid)
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
    coalesce(lo.has_outside_range, false),
    coalesce(la.has_needs_review, false),
    coalesce(la.has_identity_hold, false),
    coalesce(la.has_any_labs, false),
    coalesce(tr.has_treatment, false)
  from public.patients p
  left join lateral (
    select
      max(lr.taken_at) filter (where not public.lab_report_held_unscoped(lr.lab_report_id)) as latest_lab_at,
      bool_or(lr.status = 'needs_review' and not public.lab_report_held_unscoped(lr.lab_report_id)) as has_needs_review,
      bool_or(public.lab_report_held_unscoped(lr.lab_report_id)) as has_identity_hold,
      count(lr.id) filter (where not public.lab_report_held_unscoped(lr.lab_report_id)) > 0 as has_any_labs
    from public.lab_results lr
    where lr.patient_id = p.id
  ) la on true
  left join lateral (
    -- Same rows as public.patient_latest_results(): latest result per marker,
    -- identity-held reports and corrected originals excluded.
    select bool_or(l.status = 'outside_range') as has_outside_range
    from (
      select distinct on (lr.analyte_key) lr.status
      from public.lab_results lr
      where lr.patient_id = p.id
        and not public.lab_report_held_unscoped(lr.lab_report_id)
        and lr.original_value is null
      order by lr.analyte_key, lr.taken_at desc, lr.id desc
    ) l
  ) lo on true
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

create or replace function public.refresh_roster_summary_all()
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
    coalesce(lo.has_outside_range, false),
    coalesce(la.has_needs_review, false),
    coalesce(la.has_identity_hold, false),
    coalesce(la.has_any_labs, false),
    coalesce(tr.has_treatment, false)
  from public.patients p
  left join lateral (
    select
      max(lr.taken_at) filter (where not public.lab_report_held_unscoped(lr.lab_report_id)) as latest_lab_at,
      bool_or(lr.status = 'needs_review' and not public.lab_report_held_unscoped(lr.lab_report_id)) as has_needs_review,
      bool_or(public.lab_report_held_unscoped(lr.lab_report_id)) as has_identity_hold,
      count(lr.id) filter (where not public.lab_report_held_unscoped(lr.lab_report_id)) > 0 as has_any_labs
    from public.lab_results lr
    where lr.patient_id = p.id
  ) la on true
  left join lateral (
    -- Same rows as public.patient_latest_results(): latest result per marker,
    -- identity-held reports and corrected originals excluded.
    select bool_or(l.status = 'outside_range') as has_outside_range
    from (
      select distinct on (lr.analyte_key) lr.status
      from public.lab_results lr
      where lr.patient_id = p.id
        and not public.lab_report_held_unscoped(lr.lab_report_id)
        and lr.original_value is null
      order by lr.analyte_key, lr.taken_at desc, lr.id desc
    ) l
  ) lo on true
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

-- Deterministic tie-break (taken_at desc, id desc) so the detail and the
-- roster rollup always pick the same "latest" row. Otherwise identical to
-- 20261028154000.
create or replace function public.patient_latest_results(p_patient_id uuid)
returns table (
  analyte_key text,
  analyte_label text,
  value numeric,
  original_value numeric,
  unit text,
  status text,
  is_unmapped boolean,
  range_low numeric,
  range_high numeric,
  taken_at timestamptz
)
language sql
stable
security invoker
set search_path = pg_catalog, public
as $$
  select distinct on (lr.analyte_key)
    lr.analyte_key, lr.analyte_label, lr.value, lr.original_value, lr.unit,
    lr.status, lr.is_unmapped, lr.range_low, lr.range_high, lr.taken_at
  from public.lab_results lr
  where lr.patient_id = p_patient_id
    and not public.lab_report_held(lr.lab_report_id)
    and lr.original_value is null
  order by lr.analyte_key, lr.taken_at desc, lr.id desc;
$$;

select public.refresh_roster_summary_all();
