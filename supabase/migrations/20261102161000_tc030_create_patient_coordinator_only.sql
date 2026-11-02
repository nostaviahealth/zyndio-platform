-- TC-030 item 8 (Henry, 2 Nov 2026 12:24; Clara PR #26 M2): creating a patient
-- is a care_coordinator-only action. The UI was gated to care_coordinator in
-- PR #26, but the server still accepted physicians, so the product rule and the
-- server policy disagreed. Tighten create_patient_record()'s role gate from
-- ('physician', 'care_coordinator') to care_coordinator only. Everything else
-- is carried over verbatim from the current definition (20261027190000): aal2,
-- org binding, the staff / platform-admin / self-signup / existing-patient
-- guards, the active clinic_provisioned patient_record_links row, and the
-- patient_created audit row. The Edge Function create-patient's
-- requireClinicalStaffActor pre-check is tightened to match in the same card so
-- a physician is refused before an auth user is ever minted.
create or replace function public.create_patient_record(
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
  if not public.has_aal2() or public.current_role() <> 'care_coordinator' then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  v_org_id := public.current_org_id();

  if not exists (select 1 from auth.users where id = p_user_id) then
    raise exception 'account not found' using errcode = 'P0002';
  end if;

  if exists (select 1 from public.org_members where user_id = p_user_id) then
    raise exception 'cannot bind a patient record to a staff account' using errcode = '42501';
  end if;

  if exists (select 1 from public.platform_admins where user_id = p_user_id) then
    raise exception 'cannot bind a patient record to a platform admin account' using errcode = '42501';
  end if;

  if public.is_patient_self_signup(p_user_id) then
    raise exception 'cannot create a clinic patient record for a self-signup account'
      using errcode = '42501';
  end if;

  if exists (select 1 from public.patients where id = p_user_id) then
    raise exception 'account already has a patient record' using errcode = '42501';
  end if;

  insert into public.patients (id, org_id, display_name, mrn)
    values (p_user_id, v_org_id, p_display_name, p_mrn);

  insert into public.patient_record_links (
    app_user_id, org_id, telehealth_patient_id, status, linked_at, proof_method
  ) values (
    p_user_id,
    v_org_id,
    'clinic:' || p_user_id::text,
    'active',
    now(),
    'clinic_provisioned'
  );

  perform public._audit_log_insert(
    'patient_created', auth.uid(), p_user_id, v_org_id, '{}'::jsonb
  );
end;
$$;

revoke all on function public.create_patient_record(uuid, text, text) from public;
grant execute on function public.create_patient_record(uuid, text, text) to authenticated;
