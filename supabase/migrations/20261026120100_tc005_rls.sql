-- TC-005: enable + force RLS on every table from the schema migration and add
-- policies. org_admin is deliberately excluded from every clinical-table
-- policy (Henry: "admins manage users only"). Every staff policy ANDs
-- org_id = current_org_id() (cross-org denial) and has_aal2() (staff require
-- AAL2). Patient self-access does not require aal2 - MFA in this card is
-- scoped to the admin/staff portal, not the patient app.

alter table public.organizations enable row level security;
alter table public.organizations force row level security;

alter table public.org_members enable row level security;
alter table public.org_members force row level security;

alter table public.patients enable row level security;
alter table public.patients force row level security;

alter table public.patient_profiles enable row level security;
alter table public.patient_profiles force row level security;

alter table public.lab_reports enable row level security;
alter table public.lab_reports force row level security;

alter table public.consents enable row level security;
alter table public.consents force row level security;

alter table public.mfa_recovery_codes enable row level security;
alter table public.mfa_recovery_codes force row level security;

alter table public.auth_attempt_state enable row level security;
alter table public.auth_attempt_state force row level security;

alter table public.audit_log enable row level security;
alter table public.audit_log force row level security;

alter table public.notification_outbox enable row level security;
alter table public.notification_outbox force row level security;

alter table public.invites enable row level security;
alter table public.invites force row level security;

-- mfa_recovery_codes, auth_attempt_state, audit_log, notification_outbox get
-- zero policies below: forced RLS + no policy denies every row to every
-- client role, so they are reachable only through SECURITY DEFINER functions
-- and auth hooks owned by the table owner. Belt-and-braces: also strip the
-- table-level grants so a future policy mistake can't reopen them.
revoke all on public.mfa_recovery_codes from anon, authenticated;
revoke all on public.auth_attempt_state from anon, authenticated;
revoke all on public.audit_log from anon, authenticated;
revoke all on public.notification_outbox from anon, authenticated;

-- ---------------------------------------------------------------------------
-- organizations
-- ---------------------------------------------------------------------------

create policy organizations_self_select on public.organizations
  for select
  to authenticated
  using (id = public.current_org_id());

-- ---------------------------------------------------------------------------
-- org_members
-- ---------------------------------------------------------------------------

-- A signed-in-but-not-yet-MFA'd user can see their own role/status during
-- the sign-in flow, so this needs no has_aal2() check.
create policy org_members_self_select on public.org_members
  for select
  to authenticated
  using (user_id = auth.uid());

create policy org_members_admin_select on public.org_members
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.is_org_admin()
    and public.has_aal2()
  );

create policy org_members_admin_update on public.org_members
  for update
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.is_org_admin()
    and public.has_aal2()
  )
  with check (org_id = public.current_org_id());

-- No INSERT/DELETE policy: membership rows are created only via the
-- invite-acceptance flow and changed only via change_member_role() /
-- deactivate-user / reactivate-user (all SECURITY DEFINER / service role).

-- ---------------------------------------------------------------------------
-- patients
-- ---------------------------------------------------------------------------

create policy patients_self_select on public.patients
  for select
  to authenticated
  using (id = auth.uid());

create policy patients_self_update on public.patients
  for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy patients_staff_write_select on public.patients
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator')
  );

create policy patients_staff_write_insert on public.patients
  for insert
  to authenticated
  with check (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator')
  );

create policy patients_staff_write_update on public.patients
  for update
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator')
  )
  with check (org_id = public.current_org_id());

create policy patients_staff_read_only_select on public.patients
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() = 'read_only'
  );

-- ---------------------------------------------------------------------------
-- patient_profiles
-- ---------------------------------------------------------------------------

create policy patient_profiles_self_select on public.patient_profiles
  for select
  to authenticated
  using (patient_id = auth.uid());

create policy patient_profiles_self_update on public.patient_profiles
  for update
  to authenticated
  using (patient_id = auth.uid())
  with check (patient_id = auth.uid());

create policy patient_profiles_staff_write_select on public.patient_profiles
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator')
  );

create policy patient_profiles_staff_write_insert on public.patient_profiles
  for insert
  to authenticated
  with check (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator')
  );

create policy patient_profiles_staff_write_update on public.patient_profiles
  for update
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator')
  )
  with check (org_id = public.current_org_id());

create policy patient_profiles_staff_read_only_select on public.patient_profiles
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() = 'read_only'
  );

-- ---------------------------------------------------------------------------
-- lab_reports (patients can read + add their own; not update/delete - once
-- uploaded a report is immutable from the patient side)
-- ---------------------------------------------------------------------------

create policy lab_reports_self_select on public.lab_reports
  for select
  to authenticated
  using (patient_id = auth.uid());

create policy lab_reports_self_insert on public.lab_reports
  for insert
  to authenticated
  with check (patient_id = auth.uid());

create policy lab_reports_staff_write_select on public.lab_reports
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator')
  );

create policy lab_reports_staff_write_insert on public.lab_reports
  for insert
  to authenticated
  with check (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator')
  );

create policy lab_reports_staff_write_update on public.lab_reports
  for update
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator')
  )
  with check (org_id = public.current_org_id());

create policy lab_reports_staff_read_only_select on public.lab_reports
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() = 'read_only'
  );

-- ---------------------------------------------------------------------------
-- consents (patients grant/update their own consent)
-- ---------------------------------------------------------------------------

create policy consents_self_select on public.consents
  for select
  to authenticated
  using (patient_id = auth.uid());

create policy consents_self_insert on public.consents
  for insert
  to authenticated
  with check (patient_id = auth.uid());

create policy consents_self_update on public.consents
  for update
  to authenticated
  using (patient_id = auth.uid())
  with check (patient_id = auth.uid());

create policy consents_staff_write_select on public.consents
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator')
  );

create policy consents_staff_write_insert on public.consents
  for insert
  to authenticated
  with check (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator')
  );

create policy consents_staff_write_update on public.consents
  for update
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator')
  )
  with check (org_id = public.current_org_id());

create policy consents_staff_read_only_select on public.consents
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() = 'read_only'
  );

-- ---------------------------------------------------------------------------
-- invites (org_admin can see pending/accepted invites for their own org;
-- creating/revoking invites is an Edge Function using the service role -
-- TC-005 step 3, not a client-writable policy here)
-- ---------------------------------------------------------------------------

create policy invites_admin_select on public.invites
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.is_org_admin()
    and public.has_aal2()
  );
