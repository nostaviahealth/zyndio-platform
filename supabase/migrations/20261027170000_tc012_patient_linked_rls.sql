-- TC-012 / Clara RECORD_MATCHING #5: patient-read RLS must not expose
-- clinical rows to a verified self-signup that has no clinic binding yet.
--
-- Self-signup (patient-signup Edge Function) creates no public.patients row.
-- Staff/clinic provisioning creates patients with org_id NOT NULL.
-- Until patient_record_links + bind RPCs land (after Clara Approves the
-- revised RECORD_MATCHING.md), "linked" means "has an org-scoped patients
-- row". When links land, replace the body of current_patient_linked() with
-- an active-link check (keeping this grandfather only as a short backfill
-- bridge if needed).

create or replace function public.current_patient_linked()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.patients p
    where p.id = auth.uid()
      and p.org_id is not null
  );
$$;

revoke all on function public.current_patient_linked() from public;
grant execute on function public.current_patient_linked() to authenticated, service_role;

comment on function public.current_patient_linked() is
  'True when the JWT subject has a clinic-scoped patients row (org_id set). '
  'Self-signup accounts have no such row until bind. Later: require active '
  'patient_record_links (Clara RECORD_MATCHING #5 / PSU-TO-15).';

-- Clinical SELECTs: email confirmed AND linked/provisioned.
drop policy if exists patients_self_select on public.patients;
create policy patients_self_select on public.patients
  for select to authenticated
  using (
    id = auth.uid()
    and public.current_email_confirmed()
    and public.current_patient_linked()
  );

drop policy if exists patient_profiles_self_select on public.patient_profiles;
create policy patient_profiles_self_select on public.patient_profiles
  for select to authenticated
  using (
    patient_id = auth.uid()
    and public.current_email_confirmed()
    and public.current_patient_linked()
  );

drop policy if exists lab_reports_self_select on public.lab_reports;
create policy lab_reports_self_select on public.lab_reports
  for select to authenticated
  using (
    patient_id = auth.uid()
    and public.current_email_confirmed()
    and public.current_patient_linked()
  );

drop policy if exists consents_self_select on public.consents;
create policy consents_self_select on public.consents
  for select to authenticated
  using (
    patient_id = auth.uid()
    and public.current_email_confirmed()
    and public.current_patient_linked()
  );

-- Writes also require linked/provisioned (self-signup must not invent PHI).
drop policy if exists patients_self_update on public.patients;
create policy patients_self_update on public.patients
  for update to authenticated
  using (
    id = auth.uid()
    and public.current_email_confirmed()
    and public.current_patient_linked()
  )
  with check (id = auth.uid());

drop policy if exists patient_profiles_self_update on public.patient_profiles;
create policy patient_profiles_self_update on public.patient_profiles
  for update to authenticated
  using (
    patient_id = auth.uid()
    and public.current_email_confirmed()
    and public.current_patient_linked()
  )
  with check (
    patient_id = auth.uid()
    and org_id = (select org_id from public.patients where id = auth.uid())
  );

drop policy if exists lab_reports_self_insert on public.lab_reports;
create policy lab_reports_self_insert on public.lab_reports
  for insert to authenticated
  with check (
    patient_id = auth.uid()
    and public.current_email_confirmed()
    and public.current_patient_linked()
    and org_id = (select org_id from public.patients where id = auth.uid())
  );

drop policy if exists consents_self_insert on public.consents;
create policy consents_self_insert on public.consents
  for insert to authenticated
  with check (
    patient_id = auth.uid()
    and public.current_email_confirmed()
    and public.current_patient_linked()
    and org_id = (select org_id from public.patients where id = auth.uid())
  );

drop policy if exists consents_self_update on public.consents;
create policy consents_self_update on public.consents
  for update to authenticated
  using (
    patient_id = auth.uid()
    and public.current_email_confirmed()
    and public.current_patient_linked()
  )
  with check (
    patient_id = auth.uid()
    and org_id = (select org_id from public.patients where id = auth.uid())
  );
