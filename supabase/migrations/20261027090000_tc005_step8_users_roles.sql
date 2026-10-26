-- TC-005 step 8: backing RPC for 07-users-roles plus a gap closed while
-- wiring it up.
--
-- list_org_members(): the admin table needs each member's email, but
-- org_members carries no email column (by design - auth.users is the
-- source of truth) and the client has no RLS-visible way to read
-- auth.users. SECURITY DEFINER, same org_admin + aal2 gate as every other
-- admin RPC in this card.
create function public.list_org_members()
returns table (
  user_id uuid,
  email text,
  role public.app_role,
  status text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if not public.is_org_admin() or not public.has_aal2() then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  return query
    select m.user_id, u.email::text, m.role, m.status, m.created_at, m.updated_at
    from public.org_members m
    join auth.users u on u.id = m.user_id
    where m.org_id = public.current_org_id()
    order by m.created_at asc;
end;
$$;

revoke all on function public.list_org_members() from public;
grant execute on function public.list_org_members() to authenticated;

-- request_mfa_reset(self): requesting a reset of your own two-factor
-- sign-in is meaningless (you'd just re-enrol yourself) and the
-- 07-users-roles UI hides the action on the caller's own row - this is the
-- server-side half of that rule, matching every other own-row guard in this
-- card (reset-mfa, deactivate-user).
create or replace function public.request_mfa_reset(p_target_user_id uuid)
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

  if p_target_user_id = auth.uid() then
    raise exception 'cannot request own mfa reset' using errcode = '42501';
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
