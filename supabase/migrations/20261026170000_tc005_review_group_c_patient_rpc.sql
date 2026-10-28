-- Review group C, C1 (Clara PR #4 pre-review, L1 / probe P9): a staff
-- member could INSERT a public.patients row for ANY existing auth user id
-- in their org via patients_staff_write_insert - binding an arbitrary
-- account (another staff member's, a stranger's) as a "patient" with no
-- check that the account wants or expects that. Fix: drop the direct INSERT
-- policy entirely and replace it with a SECURITY DEFINER RPC that re-checks
-- aal2 + physician/care_coordinator server-side, and refuses to bind an
-- account that is already staff anywhere or already has a patients row
-- anywhere, before creating the row in the caller's own org. Nothing in the
-- web app, scripts, Edge Functions, seeds, or pgTAP fixtures inserted into
-- patients as a staff actor outside of this policy/these tests (grepped the
-- repo first), so there is nothing else to migrate onto the new path.
--
-- Note on scope: this schema has no separate "patient invited to an org"
-- concept (the invites table is staff-only - its role column is
-- public.app_role, which has no patient value - and the patient Flutter app
-- signs up with no org selection at all). The brief's "is in/invited to the
-- caller's org" is read here as "the resulting patients row is created in
-- the caller's org" (the v_org_id binding below), not as a precondition
-- against a pre-existing invite record, since no such record type exists
-- yet for patients. A real patient-onboarding/invite flow is a follow-up
-- card (flagged in the step summary for Henry).

drop policy patients_staff_write_insert on public.patients;

create function public.create_patient_record(
  p_user_id uuid,
  p_display_name text default null,
  p_mrn text default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org_id uuid;
begin
  if not public.has_aal2() or public.current_role() not in ('physician', 'care_coordinator') then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  v_org_id := public.current_org_id();

  if not exists (select 1 from auth.users where id = p_user_id) then
    raise exception 'account not found' using errcode = 'P0002';
  end if;

  if exists (select 1 from public.org_members where user_id = p_user_id) then
    raise exception 'cannot bind a patient record to a staff account' using errcode = '42501';
  end if;

  if exists (select 1 from public.patients where id = p_user_id) then
    raise exception 'account already has a patient record' using errcode = '42501';
  end if;

  insert into public.patients (id, org_id, display_name, mrn)
    values (p_user_id, v_org_id, p_display_name, p_mrn);

  perform public._audit_log_insert(
    'patient_created', auth.uid(), p_user_id, v_org_id, '{}'::jsonb
  );
end;
$$;

revoke all on function public.create_patient_record(uuid, text, text) from public;
grant execute on function public.create_patient_record(uuid, text, text) to authenticated;
