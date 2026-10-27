-- TC-014: invite Full name + grant rules + cancel pending invite.
--
-- 1. invites.full_name — captured at invite time; applied to
--    auth.users.raw_user_meta_data.full_name by invite-user (Edge).
-- 2. can_grant_role(actor, target) — rank check used by invite-user and
--    (defense in depth) change_member_role. org_admin can grant every
--    app_role; a lower role cannot grant above itself. Platform admin is
--    not an app_role and is never grantable here.
-- 3. finalize_invite_cancel — service_role transactional revoke + member
--    delete + audit. Auth user deletion (so re-invite is not tripped by
--    M6) stays in the Edge Function after this RPC returns.
-- 4. list_org_members returns full_name from user metadata so the admin
--    table can show the invited name instead of a guessed email local-part.

alter table public.invites
  add column if not exists full_name text;

-- ---------------------------------------------------------------------------
-- Grant hierarchy (same rules the role dropdown intends to enforce):
--   org_admin (3) > physician (2) > care_coordinator (1) > read_only (0)
-- Actor may grant a role iff target_rank <= actor_rank.
-- ---------------------------------------------------------------------------
create or replace function public.can_grant_role(
  p_actor_role public.app_role,
  p_target_role public.app_role
)
returns boolean
language sql
immutable
parallel safe
set search_path = pg_catalog, public
as $$
  select (
    case p_actor_role
      when 'org_admin' then 3
      when 'physician' then 2
      when 'care_coordinator' then 1
      when 'read_only' then 0
    end
  ) >= (
    case p_target_role
      when 'org_admin' then 3
      when 'physician' then 2
      when 'care_coordinator' then 1
      when 'read_only' then 0
    end
  );
$$;

revoke all on function public.can_grant_role(public.app_role, public.app_role) from public;
grant execute on function public.can_grant_role(public.app_role, public.app_role) to authenticated, service_role;

-- change_member_role: refuse a role the actor cannot grant (defense in
-- depth for the dropdown; invite-user enforces the same check itself).
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
    raise exception 'member not found in your organization' using errcode = 'P0002';
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

-- ---------------------------------------------------------------------------
-- Cancel a still-pending invite (same clinic, invited status only).
-- Returns the invitee's email / role / full_name so the Edge Function can
-- audit/toast and then delete the never-accepted auth.users row.
-- ---------------------------------------------------------------------------
create or replace function public.finalize_invite_cancel(
  p_target_user_id uuid,
  p_actor_user_id uuid,
  p_org_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_status text;
  v_email text;
  v_role public.app_role;
  v_full_name text;
begin
  select m.status, m.role into v_status, v_role
    from public.org_members m
    where m.user_id = p_target_user_id and m.org_id = p_org_id
    for update;

  if v_status is null then
    raise exception 'member not found in organization' using errcode = 'P0002';
  end if;

  if v_status <> 'invited' then
    raise exception 'not an invited member' using errcode = 'P0001';
  end if;

  select i.email, i.full_name, i.role
    into v_email, v_full_name, v_role
    from public.invites i
    where i.org_id = p_org_id
      and i.user_id = p_target_user_id
      and i.accepted_at is null
      and i.revoked_at is null
    order by i.created_at desc
    limit 1;

  update public.invites
    set revoked_at = now()
    where org_id = p_org_id
      and user_id = p_target_user_id
      and accepted_at is null
      and revoked_at is null;

  delete from public.org_members
    where user_id = p_target_user_id and org_id = p_org_id;

  perform public.force_sign_out(p_target_user_id);

  perform public.write_audit_log(
    'invite_cancelled',
    p_actor_user_id,
    p_target_user_id,
    p_org_id,
    jsonb_build_object(
      'email', v_email,
      'role', v_role,
      'full_name', v_full_name
    )
  );

  return jsonb_build_object(
    'email', v_email,
    'role', v_role,
    'full_name', v_full_name
  );
end;
$$;

revoke all on function public.finalize_invite_cancel(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.finalize_invite_cancel(uuid, uuid, uuid) to service_role;

-- list_org_members: surface full_name from auth user metadata.
create or replace function public.list_org_members()
returns table (
  user_id uuid,
  email text,
  full_name text,
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
    select
      m.user_id,
      u.email::text,
      nullif(btrim(coalesce(u.raw_user_meta_data->>'full_name', '')), '')::text as full_name,
      m.role,
      m.status,
      m.created_at,
      m.updated_at
    from public.org_members m
    join auth.users u on u.id = m.user_id
    where m.org_id = public.current_org_id()
    order by m.created_at asc;
end;
$$;

revoke all on function public.list_org_members() from public;
grant execute on function public.list_org_members() to authenticated;
