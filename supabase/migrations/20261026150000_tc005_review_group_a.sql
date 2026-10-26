-- TC-005 PR #4 review, group A (Clara's pre-review, Henry's binding rulings).
--
-- A1 (H1): org_members role/status/user_id must not change via a direct
-- client UPDATE - change_member_role() (audited) and the Edge Functions
-- (deactivate-user/reactivate-user/accept-invite, all service_role) are the
-- only sanctioned paths. Drop the policy AND revoke the table privilege, so
-- the denial holds even if a future migration re-adds a permissive policy.
drop policy if exists org_members_admin_update on public.org_members;
revoke update on public.org_members from authenticated;

-- A2 (H2): read_only gets no clinical detail at the DB level. patients
-- carries only list/display columns (display_name, mrn) so its existing
-- read_only SELECT policy already satisfies "list view only" and stays;
-- patient_profiles/lab_reports/consents hold the actual clinical payload
-- and lose read_only's SELECT entirely.
drop policy if exists patient_profiles_staff_read_only_select on public.patient_profiles;
drop policy if exists lab_reports_staff_read_only_select on public.lab_reports;
drop policy if exists consents_staff_read_only_select on public.consents;

-- A5 (Henry ruling 2): care coordinators must not confirm/edit lab values
-- ("Needs review") at the DB level - only physicians may UPDATE lab_reports.
-- Replace the shared physician+care_coordinator UPDATE policy with a
-- physician-only one. INSERT/SELECT for care_coordinator are unchanged
-- (uploading/viewing a report is not "confirming" it).
drop policy if exists lab_reports_staff_write_update on public.lab_reports;

create policy lab_reports_physician_update on public.lab_reports
  for update
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() = 'physician'
  )
  with check (org_id = public.current_org_id());

-- M1: a patient could move their own clinical rows to a different org by
-- setting org_id on a self-writable row directly. patients.org_id becomes
-- immutable for everyone going through the patient self-update policy (the
-- staff/admin paths never touch this trigger - they don't update patients
-- rows cross-org in the first place, enforced separately by their own
-- WITH CHECK). The three patient-owned child tables pin org_id to the
-- patient's own (now-immutable) org on every self insert/update.
create function public.enforce_patients_org_id_immutable()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if NEW.org_id is distinct from OLD.org_id and auth.uid() = OLD.id then
    raise exception 'org_id cannot be changed' using errcode = '42501';
  end if;
  return NEW;
end;
$$;

create trigger trg_enforce_patients_org_id_immutable
  before update on public.patients
  for each row execute function public.enforce_patients_org_id_immutable();

drop policy if exists patient_profiles_self_update on public.patient_profiles;
create policy patient_profiles_self_update on public.patient_profiles
  for update
  to authenticated
  using (patient_id = auth.uid())
  with check (
    patient_id = auth.uid()
    and org_id = (select org_id from public.patients where id = auth.uid())
  );

drop policy if exists lab_reports_self_insert on public.lab_reports;
create policy lab_reports_self_insert on public.lab_reports
  for insert
  to authenticated
  with check (
    patient_id = auth.uid()
    and org_id = (select org_id from public.patients where id = auth.uid())
  );

drop policy if exists consents_self_insert on public.consents;
create policy consents_self_insert on public.consents
  for insert
  to authenticated
  with check (
    patient_id = auth.uid()
    and org_id = (select org_id from public.patients where id = auth.uid())
  );

drop policy if exists consents_self_update on public.consents;
create policy consents_self_update on public.consents
  for update
  to authenticated
  using (patient_id = auth.uid())
  with check (
    patient_id = auth.uid()
    and org_id = (select org_id from public.patients where id = auth.uid())
  );

-- A4 (Henry ruling 1): a minimal platform-level "Zyndio admin" concept, kept
-- separate from org_admin. No client grants, no policies (same
-- zero-access-except-SECURITY-DEFINER pattern as audit_log etc). Seeded only
-- by the documented bootstrap script (see admin-setup.md) - never by
-- default, never by an in-app action.
create table public.platform_admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.platform_admins enable row level security;
alter table public.platform_admins force row level security;
revoke all on public.platform_admins from anon, authenticated;

create function public.is_zyndio_admin()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (select 1 from public.platform_admins where user_id = auth.uid());
$$;

-- An org admin cannot reset 2FA themselves (that path is Zyndio-admin-only,
-- enforced in the reset-mfa Edge Function via is_zyndio_admin()); they can
-- only *request* a reset. This RPC is audited and touches nothing but
-- audit_log + notification_outbox - it resets no factor, no recovery code.
create function public.request_mfa_reset(p_target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org_id uuid;
  v_target_org_id uuid;
  v_admin_id uuid;
begin
  if not public.is_org_admin() or not public.has_aal2() then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  v_org_id := public.current_org_id();

  select org_id into v_target_org_id
    from public.org_members
    where user_id = p_target_user_id and org_id = v_org_id;

  if v_target_org_id is null then
    raise exception 'member not found in your organization' using errcode = 'P0002';
  end if;

  perform public.write_audit_log(
    'mfa_reset_requested', auth.uid(), p_target_user_id, v_org_id, '{}'::jsonb
  );

  for v_admin_id in select user_id from public.platform_admins loop
    insert into public.notification_outbox (user_id, org_id, type, payload)
    values (v_admin_id, v_org_id, 'mfa_reset_requested', jsonb_build_object('target_user_id', p_target_user_id, 'requested_by', auth.uid()));
  end loop;
end;
$$;

revoke all on function public.request_mfa_reset(uuid) from public;
grant execute on function public.request_mfa_reset(uuid) to authenticated;
