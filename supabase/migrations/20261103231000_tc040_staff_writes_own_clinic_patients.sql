-- TC-040: clinic staff can only write lab reports, consents and patient
-- profiles about patients of THEIR OWN clinic, and a written row can never be
-- moved to another patient or another clinic afterwards.
--
-- Before: the staff INSERT/UPDATE policies on lab_reports, consents and
-- patient_profiles only checked org_id = current_org_id(). patient_id was not
-- checked at all, so a physician of clinic B could
--   * insert a clinic-B row about clinic-A patient A1 (Clara, PR #33 M1: with
--     pdf_path = A1's file, the forged row that tried to open A1's PDF), and
--   * re-point an existing clinic-B row at A1 (UPDATE ... set patient_id).
-- The read side was closed in PR #33 (storage rule checks the folder's
-- patient clinic); this closes the write side (TC-040 card items 1-3, 5).
--
-- 1. WITH CHECK on every staff write policy now also requires the row's
--    patient to be a patient of the caller's clinic. The clinic is checked
--    explicitly (p.org_id = current_org_id()), not left to patients RLS, so a
--    future widening of patients SELECT can't reopen this (pgTAP 746 probes it).
--    USING clauses are unchanged (ALTER POLICY ... WITH CHECK only).
-- 2. patient_id and org_id are immutable for client writes (roles
--    authenticated / anon) on lab_reports, consents and patient_profiles: a
--    BEFORE UPDATE trigger raises 42501 if either changes. Server-side code
--    (service_role, SECURITY DEFINER functions running as the owner,
--    migrations) is not blocked, so a reviewed clinic-transfer path (TC-034
--    item 69) stays possible. Same-value updates (e.g. upserts) still pass.
--    Patients' own write policies already pin patient_id = auth.uid() and
--    org_id = their clinic; the trigger changes nothing for them.
-- lab_results (biomarker rows) has no client write privilege or policy at all
-- (written only by the server pipeline); 746 pins that.
-- Forward-only; no data changes.

alter policy lab_reports_staff_write_insert on public.lab_reports
  with check (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator')
    and exists (select 1 from public.patients p
                 where p.id = lab_reports.patient_id
                   and p.org_id = public.current_org_id())
  );

alter policy lab_reports_physician_update on public.lab_reports
  with check (
    org_id = public.current_org_id()
    and exists (select 1 from public.patients p
                 where p.id = lab_reports.patient_id
                   and p.org_id = public.current_org_id())
  );

alter policy consents_staff_write_insert on public.consents
  with check (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator')
    and exists (select 1 from public.patients p
                 where p.id = consents.patient_id
                   and p.org_id = public.current_org_id())
  );

alter policy consents_staff_write_update on public.consents
  with check (
    org_id = public.current_org_id()
    and exists (select 1 from public.patients p
                 where p.id = consents.patient_id
                   and p.org_id = public.current_org_id())
  );

alter policy patient_profiles_staff_write_insert on public.patient_profiles
  with check (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator')
    and exists (select 1 from public.patients p
                 where p.id = patient_profiles.patient_id
                   and p.org_id = public.current_org_id())
  );

alter policy patient_profiles_staff_write_update on public.patient_profiles
  with check (
    org_id = public.current_org_id()
    and exists (select 1 from public.patients p
                 where p.id = patient_profiles.patient_id
                   and p.org_id = public.current_org_id())
  );

create function public._enforce_patient_and_clinic_immutable()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if current_user in ('authenticated', 'anon')
     and (new.patient_id is distinct from old.patient_id
          or new.org_id is distinct from old.org_id) then
    raise exception '%: patient_id and org_id cannot be changed', tg_table_name
      using errcode = '42501';
  end if;
  return new;
end;
$$;
revoke all on function public._enforce_patient_and_clinic_immutable() from public, anon, authenticated;

create trigger lab_reports_patient_clinic_immutable
  before update of patient_id, org_id on public.lab_reports
  for each row execute function public._enforce_patient_and_clinic_immutable();
create trigger consents_patient_clinic_immutable
  before update of patient_id, org_id on public.consents
  for each row execute function public._enforce_patient_and_clinic_immutable();
create trigger patient_profiles_patient_clinic_immutable
  before update of patient_id, org_id on public.patient_profiles
  for each row execute function public._enforce_patient_and_clinic_immutable();
