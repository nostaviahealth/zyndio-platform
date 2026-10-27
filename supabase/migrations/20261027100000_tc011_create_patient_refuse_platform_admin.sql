-- TC-011: create_patient_record must refuse Zyndio platform_admins accounts
-- (Clara PR #4 low). Staff org_members were already refused; platform_admins
-- are not org_members, so they slipped through.

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

  if exists (select 1 from public.platform_admins where user_id = p_user_id) then
    raise exception 'cannot bind a patient record to a platform admin account' using errcode = '42501';
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
