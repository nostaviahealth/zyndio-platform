-- TC-018 item 4 (L36): change_member_role's cross-org branch raised errcode
-- P0002 ("member not found in your organization"), which PostgREST's
-- default SQLSTATE mapping turns into HTTP 500. Every other cross-clinic
-- action (cancel-invite, deactivate-user, reset-mfa) returns 404 not_found
-- instead. Recreate the function raising 'PT404' for that branch only -
-- PostgREST maps a 'PTxyz' sqlstate directly to HTTP status xyz. Everything
-- else (authorization, grant-hierarchy check, update, audit) is unchanged.

create or replace function public.change_member_role(
  p_target_user_id uuid,
  p_new_role public.app_role
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org_id uuid;
  v_old_role public.app_role;
  v_actor_role public.app_role;
begin
  if not public.is_org_admin() or not public.has_aal2() then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  select org_id, role into v_org_id, v_actor_role
    from public.org_members where user_id = auth.uid();

  if not public.can_grant_role(v_actor_role, p_new_role) then
    raise exception 'role not grantable' using errcode = '42501';
  end if;

  select role into v_old_role
    from public.org_members
    where user_id = p_target_user_id and org_id = v_org_id;

  if v_old_role is null then
    raise exception 'member not found in your organization' using errcode = 'PT404';
  end if;

  update public.org_members
    set role = p_new_role, updated_at = now()
    where user_id = p_target_user_id and org_id = v_org_id;

  perform public._audit_log_insert(
    'role_changed', auth.uid(), p_target_user_id, v_org_id,
    jsonb_build_object('from', v_old_role, 'to', p_new_role)
  );
end;
$$;
