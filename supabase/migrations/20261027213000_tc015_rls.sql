-- TC-015 slice 1: RLS for the new clinical read model. Mirrors the TC-005
-- clinical convention - every staff policy ANDs org_id = current_org_id()
-- (cross-org denial) and has_aal2(). No org_admin policy anywhere (admins
-- manage users only).
--
-- Leo ruling R1 (Henry 26 Oct): read_only may see the roster but gets NO
-- clinical detail. So:
--   * lab_results / patient_treatments  - physician + care_coordinator only
--     (read_only has no policy => denied). This is what makes read_only's
--     detail open return not-found and its trend empty.
--   * patient_roster_meta               - physician + care_coordinator AND
--     read_only (roster demographics are roster data, which read_only sees).
-- Patients read their own rows (self policies) for the patient app.

-- ---------------------------------------------------------------------------
-- lab_results
-- ---------------------------------------------------------------------------

create policy lab_results_self_select on public.lab_results
  for select
  to authenticated
  using (patient_id = auth.uid());

create policy lab_results_staff_select on public.lab_results
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator')
  );

-- ---------------------------------------------------------------------------
-- patient_treatments
-- ---------------------------------------------------------------------------

create policy patient_treatments_self_select on public.patient_treatments
  for select
  to authenticated
  using (patient_id = auth.uid());

create policy patient_treatments_staff_select on public.patient_treatments
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator')
  );

-- ---------------------------------------------------------------------------
-- patient_roster_meta (read_only included - roster data, not clinical detail)
-- ---------------------------------------------------------------------------

create policy patient_roster_meta_self_select on public.patient_roster_meta
  for select
  to authenticated
  using (patient_id = auth.uid());

create policy patient_roster_meta_staff_select on public.patient_roster_meta
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator', 'read_only')
  );
