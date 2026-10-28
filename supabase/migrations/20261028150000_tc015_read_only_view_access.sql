-- TC-015 fix round: read_only access flip (Leo ruling, 28 Oct, supersedes
-- R1 26 Oct). Card item 4 now reads "Physician, Care coordinator and
-- Read-only can view; every detail open is audited; read_only gets no
-- actions." read_only gains the same own-clinic view as physician/
-- care_coordinator - same detail page, same disabled entry points, no extra
-- hiding - and every open it makes is audited like any other role. It gains
-- no write/action RPC: those all gate on current_role() in ('physician',
-- 'care_coordinator') or is_org_admin(), neither of which read_only ever
-- satisfies, and no insert/update/delete grant exists on the clinical
-- tables for any authenticated role (20261027212000_tc015_schema.sql
-- L105-107).

-- ---------------------------------------------------------------------------
-- lab_results / patient_treatments: widen the staff-select policies to
-- include read_only. Cross-org and has_aal2() stay exactly as before.
-- ---------------------------------------------------------------------------

drop policy lab_results_staff_select on public.lab_results;
create policy lab_results_staff_select on public.lab_results
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator', 'read_only')
  );

drop policy patient_treatments_staff_select on public.patient_treatments;
create policy patient_treatments_staff_select on public.patient_treatments
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator', 'read_only')
  );

-- ---------------------------------------------------------------------------
-- lab_reports: the TC-005 review-group-A ruling (H2, 20261026150000) dropped
-- read_only's SELECT entirely ("no clinical detail at the DB level"). The
-- fix-round ruling supersedes that: read_only now gets the same own-clinic
-- detail/trend view as physician/care_coordinator, which depends on
-- lab_reports for the identity_hold exclusion (patient_trend's NOT EXISTS
-- check, patient_latest_results's join) - without this, that exclusion
-- would silently fail open for read_only. Mirrors
-- lab_reports_staff_write_select, select-only, no write grant.
-- ---------------------------------------------------------------------------

create policy lab_reports_staff_read_only_select on public.lab_reports
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() = 'read_only'
  );

-- ---------------------------------------------------------------------------
-- open_patient_detail(): widen the clinical-detail gate to admit read_only.
-- The audit write is unconditional on a visible open, so read_only opens are
-- now audited exactly like physician/care_coordinator. The not-found
-- contract for invisible patients (other clinic / unknown id) and the
-- treatment key whitelist are unchanged byte-for-byte.
-- ---------------------------------------------------------------------------

create or replace function public.open_patient_detail(p_patient_id uuid)
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
  -- Clinical-detail gate (mirrors the lab_results RLS). read_only is
  -- admitted here (fix round) with the same own-clinic visibility as
  -- physician/care_coordinator.
  if auth.uid() is null
     or not public.has_aal2()
     or public.current_role() not in ('physician', 'care_coordinator', 'read_only') then
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
