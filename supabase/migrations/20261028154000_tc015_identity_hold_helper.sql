-- TC-015 fix round (Leo ruling, 28 Oct): the identity-hold exclusion in
-- physician_roster_base, patient_trend and patient_latest_results must not
-- depend on the caller being able to SELECT lab_reports (read_only cannot,
-- per 20261028153000 - H2 stands). lab_report_held() is SECURITY DEFINER so
-- it can see lab_reports.identity_hold regardless of the caller's own grants,
-- and fails CLOSED (an unreadable/nonexistent report counts as held) so a
-- caller can never turn "I can't see this report" into "treat it as not
-- held". The three RPCs stay SECURITY INVOKER - only this single boolean
-- check is lifted out to a definer function, everything else about their
-- own-clinic RLS enforcement is unchanged.

create function public.lab_report_held(p_lab_report_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select coalesce(
    (select identity_hold from public.lab_reports where id = p_lab_report_id),
    true
  );
$$;

revoke all on function public.lab_report_held(uuid) from public, anon;
grant execute on function public.lab_report_held(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- physician_roster_base(): identity-hold flag/latest-lab-date aggregates now
-- go through lab_report_held() instead of joining lab_reports directly.
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
language sql
stable
security invoker
set search_path = pg_catalog, public
as $$
  select
    p.id,
    p.display_name,
    p.mrn,
    m.sex,
    m.birth_date,
    m.program_started_on,
    la.latest_lab_at,
    m.last_activity_at,
    coalesce(m.open_questions, 0),
    array_remove(array[
      case when tr.has_treatment then 'clinical_context' end,
      case when la.has_outside_range then 'outside_range' end,
      case when la.has_needs_review then 'needs_review' end,
      case when la.has_identity_hold then 'identity_hold' end,
      case when not coalesce(la.has_any_labs, false) then 'missing_labs' end,
      case when coalesce(m.open_questions, 0) > 0 then 'question_waiting' end
    ], null)
  from public.patients p
  left join public.patient_roster_meta m on m.patient_id = p.id
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
  where p.org_id = public.current_org_id();
$$;

-- ---------------------------------------------------------------------------
-- patient_trend(): identity-hold exclusion via lab_report_held() instead of
-- NOT EXISTS against lab_reports.
-- ---------------------------------------------------------------------------

create or replace function public.patient_trend(
  p_patient_id uuid,
  p_analyte text,
  p_period text default '6M'
)
returns table (
  taken_at timestamptz,
  value numeric,
  original_value numeric,
  unit text,
  status text,
  range_low numeric,
  range_high numeric
)
language sql
stable
security invoker
set search_path = pg_catalog, public
as $$
  select lr.taken_at, lr.value, lr.original_value, lr.unit, lr.status, lr.range_low, lr.range_high
  from public.lab_results lr
  where lr.patient_id = p_patient_id
    and lr.analyte_key = p_analyte
    and lr.status <> 'needs_review'
    and not lr.is_unmapped
    and not public.lab_report_held(lr.lab_report_id)
    and lr.taken_at >= case upper(coalesce(p_period, '6M'))
      when '3M' then now() - interval '3 months'
      when '6M' then now() - interval '6 months'
      when '1Y' then now() - interval '12 months'
      when 'ALL' then '-infinity'::timestamptz
      else now() - interval '6 months'
    end
  order by lr.taken_at;
$$;

-- ---------------------------------------------------------------------------
-- patient_latest_results(): identity-hold exclusion via lab_report_held()
-- instead of a join on lab_reports.
-- ---------------------------------------------------------------------------

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
  order by lr.analyte_key, lr.taken_at desc;
$$;
