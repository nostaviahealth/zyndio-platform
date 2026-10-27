-- TC-015 slice 1: the read-model RPCs. All SECURITY INVOKER (Leo ruling 3) so
-- RLS is the enforcement - no definer-with-own-checks. A physician/
-- care_coordinator in the same org at aal2 sees the list + detail; read_only
-- sees the roster only; another clinic sees nothing (same not-found as an
-- unknown id, never a distinct "forbidden").

-- ---------------------------------------------------------------------------
-- physician_roster_base(): one row per visible patient with demographics,
-- latest lab date, and the POR-02 flag set as text keys. Built set-based with
-- lateral aggregate joins (no per-row correlated subquery / no N+1). RLS of
-- the underlying tables applies with the caller's rights (invoker): read_only
-- sees no lab_results, so its lab-derived flags degrade to 'missing_labs'
-- rather than leaking clinical state. Shared by the roster + chip-count RPCs.
-- ---------------------------------------------------------------------------

create function public.physician_roster_base()
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
      max(lr.taken_at) filter (where not rep.identity_hold) as latest_lab_at,
      bool_or(lr.status = 'outside_range' and not rep.identity_hold) as has_outside_range,
      bool_or(lr.status = 'needs_review' and not rep.identity_hold) as has_needs_review,
      bool_or(rep.identity_hold) as has_identity_hold,
      count(lr.id) filter (where not rep.identity_hold) > 0 as has_any_labs
    from public.lab_results lr
    join public.lab_reports rep on rep.id = lr.lab_report_id
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
-- physician_patient_roster(): server-paginated, searchable, filtered roster.
-- 'flagged'           = any attention flag (outside_range / needs_review /
--                       identity_hold / question_waiting; clinical_context is
--                       context, not an attention flag).
-- 'questions_waiting' = patients with an open question, sorted OLDEST first
--                       (copy-deck); every other view sorts recent-activity
--                       desc. count(*) over () returns the pre-limit total in
--                       one pass. Limit capped at 100.
-- ---------------------------------------------------------------------------

create function public.physician_patient_roster(
  p_search text default null,
  p_filter text default 'all',
  p_sort text default 'recent',
  p_limit int default 50,
  p_offset int default 0
)
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
  flags text[],
  total_count bigint
)
language sql
stable
security invoker
set search_path = pg_catalog, public
as $$
  with filtered as (
    select r.*
    from public.physician_roster_base() r
    where
      case coalesce(p_filter, 'all')
        when 'flagged' then r.flags && array['outside_range', 'needs_review', 'identity_hold', 'question_waiting']
        when 'missing_labs' then 'missing_labs' = any(r.flags)
        when 'questions_waiting' then 'question_waiting' = any(r.flags)
        else true
      end
      and (
        p_search is null or p_search = ''
        or r.display_name ilike '%' || p_search || '%'
        or r.mrn ilike '%' || p_search || '%'
      )
  )
  select
    f.patient_id,
    f.display_name,
    f.mrn,
    f.sex,
    f.birth_date,
    f.program_started_on,
    f.latest_lab_at,
    f.last_activity_at,
    f.open_questions,
    f.flags,
    count(*) over () as total_count
  from filtered f
  order by
    case when coalesce(p_filter, 'all') = 'questions_waiting' then f.last_activity_at end asc nulls last,
    case when coalesce(p_filter, 'all') <> 'questions_waiting' then f.last_activity_at end desc nulls last,
    f.display_name asc
  limit least(coalesce(p_limit, 50), 100)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

-- ---------------------------------------------------------------------------
-- physician_roster_chip_counts(): the four roster chips (All / Flagged /
-- Missing labs / Questions waiting) over the caller's whole org in one pass.
-- ---------------------------------------------------------------------------

create function public.physician_roster_chip_counts()
returns table (
  all_count bigint,
  flagged_count bigint,
  missing_labs_count bigint,
  questions_waiting_count bigint
)
language sql
stable
security invoker
set search_path = pg_catalog, public
as $$
  select
    count(*),
    count(*) filter (where r.flags && array['outside_range', 'needs_review', 'identity_hold', 'question_waiting']),
    count(*) filter (where 'missing_labs' = any(r.flags)),
    count(*) filter (where 'question_waiting' = any(r.flags))
  from public.physician_roster_base() r;
$$;

-- ---------------------------------------------------------------------------
-- patient_trend(): the trend series for one analyte. Excludes needs_review and
-- unmapped values and any result on an identity-hold report (Leo ruling 5).
-- Corrected points keep original_value ("was <x>"). Period window bounds
-- taken_at (3M / 6M / 1Y / ALL, default 6M). RLS denies read_only / cross-org
-- at the lab_results layer, so they get an empty series.
-- ---------------------------------------------------------------------------

create function public.patient_trend(
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
    and not exists (
      select 1 from public.lab_reports rep
      where rep.id = lr.lab_report_id and rep.identity_hold
    )
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
-- patient_latest_results(): the latest value per analyte for the Labs-tab
-- summary. Excludes identity-hold reports entirely (Leo ruling 5). A
-- *correction* amends a historical value, so it is not a new "latest" draw
-- (original_value is not null) and is skipped here - the summary shows the
-- most recent genuine measurement, while patient_trend still plots the
-- corrected point with its "was <x>" annotation. needs_review values DO appear
-- here (with their status) so the Labs tab can show "Needs review".
-- ---------------------------------------------------------------------------

create function public.patient_latest_results(p_patient_id uuid)
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
  join public.lab_reports rep on rep.id = lr.lab_report_id
  where lr.patient_id = p_patient_id
    and not rep.identity_hold
    and lr.original_value is null
  order by lr.analyte_key, lr.taken_at desc;
$$;

-- ---------------------------------------------------------------------------
-- open_patient_detail(): the audited detail open. Visibility is the clinical-
-- detail rule (same org, aal2, physician/care_coordinator) - read_only and
-- other clinics fall through to the same not-found NULL as an unknown id, and
-- no audit row is written for an invisible patient. On a visible open it
-- returns the whitelisted header + treatment context (name/started_on/status/
-- source, built from an explicit key whitelist so a dose can never leak) and
-- writes exactly ONE 'patient_detail_opened' row via write_audit_log.
-- ---------------------------------------------------------------------------

create function public.open_patient_detail(p_patient_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare
  v_org uuid := public.current_org_id();
  v_patient public.patients;
  v_meta public.patient_roster_meta;
  v_treatment public.patient_treatments;
  v_result jsonb;
begin
  -- Clinical-detail gate (mirrors the lab_results RLS). read_only is excluded
  -- here, so its open returns not-found exactly like a cross-org / unknown id.
  if auth.uid() is null
     or not public.has_aal2()
     or public.current_role() not in ('physician', 'care_coordinator') then
    return null;
  end if;

  -- Visibility read through RLS (invoker): absent => not-found for all of
  -- other-clinic / unknown id, with no audit row.
  select * into v_patient
    from public.patients
    where id = p_patient_id and org_id = v_org;
  if v_patient.id is null then
    return null;
  end if;

  select * into v_meta
    from public.patient_roster_meta
    where patient_id = p_patient_id and org_id = v_org;

  select * into v_treatment
    from public.patient_treatments
    where patient_id = p_patient_id and org_id = v_org
    order by started_on desc nulls last, created_at desc
    limit 1;

  v_result := jsonb_build_object(
    'patient_id', v_patient.id,
    'display_name', v_patient.display_name,
    'mrn', v_patient.mrn,
    'sex', v_meta.sex,
    'birth_date', v_meta.birth_date,
    'program_started_on', v_meta.program_started_on,
    'last_activity_at', v_meta.last_activity_at,
    -- Explicit key whitelist (never a strip): a stored dose cannot reach here.
    'treatment', case when v_treatment.patient_id is not null then
      jsonb_build_object(
        'name', v_treatment.name,
        'started_on', v_treatment.started_on,
        'status', v_treatment.status,
        'source', v_treatment.source
      ) else null end
  );

  perform public.write_audit_log(
    'patient_detail_opened', auth.uid(), p_patient_id, v_org, '{}'::jsonb
  );

  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants: authenticated may execute; strip public/anon.
-- ---------------------------------------------------------------------------

revoke all on function public.physician_roster_base() from public, anon;
revoke all on function public.physician_patient_roster(text, text, text, int, int) from public, anon;
revoke all on function public.physician_roster_chip_counts() from public, anon;
revoke all on function public.patient_trend(uuid, text, text) from public, anon;
revoke all on function public.patient_latest_results(uuid) from public, anon;
revoke all on function public.open_patient_detail(uuid) from public, anon;

grant execute on function public.physician_roster_base() to authenticated;
grant execute on function public.physician_patient_roster(text, text, text, int, int) to authenticated;
grant execute on function public.physician_roster_chip_counts() to authenticated;
grant execute on function public.patient_trend(uuid, text, text) to authenticated;
grant execute on function public.patient_latest_results(uuid) to authenticated;
grant execute on function public.open_patient_detail(uuid) to authenticated;
