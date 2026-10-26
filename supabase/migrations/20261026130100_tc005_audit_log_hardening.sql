-- TC-005 step 2 review fix (Leo): public.write_audit_log() carried the
-- default PUBLIC execute grant from step 1 and trusted every caller-supplied
-- argument (actor, target, org, event type) with no server-side check that
-- the caller actually was that actor. Any authenticated (or, before any
-- explicit revoke, even anon) session could forge arbitrary audit rows -
-- e.g. write a fake 'role_changed' event attributing someone else's action
-- to a different actor/org. Does not edit any committed migration file.
--
-- Fix: split the table write into two functions.
-- - public._audit_log_insert(): the unguarded internal writer. Only the
--   owner (and SECURITY DEFINER functions running as the owner) can call
--   it - no EXECUTE grant to public/anon/authenticated.
-- - public.write_audit_log(): the client-facing entry point. service_role
--   may write any row (trusted server-side callers: Edge Functions, admin
--   scripts). Every other caller must be proving the row describes their
--   own action: signed in, acting as themselves (p_actor_user_id =
--   auth.uid()), at aal2, inside their own active-membership org
--   (p_org_id = current_org_id()).
--
-- Every existing SECURITY DEFINER function that wrote audit rows internally
-- (change_member_role in the schema migration; the two auth hooks,
-- generate_recovery_codes, and consume_recovery_code in 20261026130000) is
-- switched to call _audit_log_insert directly instead of going back through
-- the now-guarded write_audit_log - their own server-side logic already
-- establishes who's allowed to write what, so re-checking "is the caller
-- acting as themselves at aal2" there would wrongly reject MFA-hook writes
-- (the hooks run under supabase_auth_admin and mfa-lockout events are
-- inherently about someone who is NOT yet at aal2) and recovery-code writes
-- (consume_recovery_code is deliberately aal1-callable). Bodies are
-- otherwise copied unchanged from 20261026120000_tc005_schema.sql and
-- 20261026130000_tc005_auth_hooks.sql.

-- ---------------------------------------------------------------------------
-- internal writer: no client role may ever call this directly.
-- ---------------------------------------------------------------------------

create function public._audit_log_insert(
  p_event_type text,
  p_actor_user_id uuid,
  p_target_user_id uuid,
  p_org_id uuid,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  insert into public.audit_log (actor_user_id, target_user_id, org_id, event_type, metadata)
  values (p_actor_user_id, p_target_user_id, p_org_id, p_event_type, p_metadata);
end;
$$;

revoke all on function public._audit_log_insert(text, uuid, uuid, uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- change_member_role (schema migration): same body, writes via the internal
-- function now. Already does its own is_org_admin() + has_aal2() + own-org
-- checks before reaching the audit write, so nothing else changes.
-- ---------------------------------------------------------------------------

create or replace function public.change_member_role(p_target_user_id uuid, p_new_role public.app_role)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org_id uuid;
  v_old_role public.app_role;
begin
  if not public.is_org_admin() or not public.has_aal2() then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  select org_id into v_org_id from public.org_members where user_id = auth.uid();

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
-- auth hooks (20261026130000): same bodies, audit writes via the internal
-- function.
-- ---------------------------------------------------------------------------

create or replace function auth_hooks.password_verification_attempt(event jsonb)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := (event ->> 'user_id')::uuid;
  v_valid boolean := coalesce((event ->> 'valid')::boolean, false);
  v_state public.auth_attempt_state;
  v_bump record;
  v_org_id uuid;
begin
  if v_valid then
    select * into v_state from public.auth_attempt_state where user_id = v_user_id for update;

    if v_state.locked_until is not null and v_state.locked_until > now() then
      -- the one deliberately distinguishable response in this design: a
      -- CORRECT password on an already-locked account.
      return jsonb_build_object('decision', 'reject', 'message', 'locked');
    end if;

    insert into public.auth_attempt_state (user_id, wrong_count, locked_until, password_verified_at)
    values (v_user_id, 0, null, now())
    on conflict (user_id) do update
      set wrong_count = 0, locked_until = null, password_verified_at = now(), updated_at = now();

    return jsonb_build_object('decision', 'continue');
  end if;

  -- wrong password: always "continue" - never reveal lockout/account state
  -- off the back of a wrong password.
  select * into v_bump from public.bump_wrong_attempt(v_user_id);

  if v_bump.just_locked then
    select org_id into v_org_id from public.org_members where user_id = v_user_id;
    perform public._audit_log_insert(
      'password_lockout', v_user_id, v_user_id, v_org_id,
      jsonb_build_object('wrong_count', v_bump.wrong_count, 'locked_until', v_bump.locked_until)
    );
  end if;

  return jsonb_build_object('decision', 'continue');
end;
$$;

create or replace function auth_hooks.mfa_verification_attempt(event jsonb)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := (event ->> 'user_id')::uuid;
  v_valid boolean := coalesce((event ->> 'valid')::boolean, false);
  v_state public.auth_attempt_state;
  v_bump record;
  v_org_id uuid;
begin
  select * into v_state from public.auth_attempt_state where user_id = v_user_id for update;

  if v_state.locked_until is not null and v_state.locked_until > now() then
    return jsonb_build_object('decision', 'reject', 'message', 'locked');
  end if;

  if v_state.password_verified_at is null or v_state.password_verified_at < now() - interval '10 minutes' then
    return jsonb_build_object('decision', 'reject', 'message', 'challenge_expired');
  end if;

  if v_valid then
    update public.auth_attempt_state
      set wrong_count = 0, locked_until = null, updated_at = now()
      where user_id = v_user_id;
    return jsonb_build_object('decision', 'continue');
  end if;

  select * into v_bump from public.bump_wrong_attempt(v_user_id);

  if v_bump.just_locked then
    select org_id into v_org_id from public.org_members where user_id = v_user_id;
    perform public._audit_log_insert(
      'mfa_lockout', v_user_id, v_user_id, v_org_id,
      jsonb_build_object('wrong_count', v_bump.wrong_count, 'locked_until', v_bump.locked_until)
    );
  end if;

  return jsonb_build_object('decision', 'continue');
end;
$$;

-- ---------------------------------------------------------------------------
-- recovery codes (20261026130000): same bodies, audit writes via the
-- internal function.
-- ---------------------------------------------------------------------------

create or replace function public.generate_recovery_codes()
returns text[]
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_factor_id uuid;
  v_codes text[] := '{}';
  v_code text;
  i int;
begin
  if v_user_id is null or not public.has_aal2() then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  select id into v_factor_id
    from auth.mfa_factors
    where user_id = v_user_id and factor_type = 'totp' and status = 'verified'
    order by created_at desc
    limit 1;

  if v_factor_id is null then
    raise exception 'no verified authenticator enrolled' using errcode = 'P0003';
  end if;

  delete from public.mfa_recovery_codes where user_id = v_user_id;

  for i in 1..10 loop
    v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
    v_codes := array_append(v_codes, v_code);
    insert into public.mfa_recovery_codes (user_id, factor_id, code_hash)
      values (v_user_id, v_factor_id, extensions.crypt(v_code, extensions.gen_salt('bf')));
  end loop;

  delete from public.mfa_reenrollment_required where user_id = v_user_id;

  perform public._audit_log_insert(
    'recovery_codes_regenerated', v_user_id, v_user_id,
    (select org_id from public.org_members where user_id = v_user_id),
    '{}'::jsonb
  );

  return v_codes;
end;
$$;

create or replace function public.consume_recovery_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_state public.auth_attempt_state;
  v_bump record;
  v_org_id uuid;
  v_row public.mfa_recovery_codes;
begin
  if v_user_id is null then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  select * into v_state from public.auth_attempt_state where user_id = v_user_id for update;

  if v_state.locked_until is not null and v_state.locked_until > now() then
    return jsonb_build_object('status', 'locked');
  end if;

  select * into v_row
    from public.mfa_recovery_codes
    where user_id = v_user_id
      and used_at is null
      and code_hash = extensions.crypt(p_code, code_hash)
    limit 1;

  select org_id into v_org_id from public.org_members where user_id = v_user_id;

  if v_row.id is null then
    select * into v_bump from public.bump_wrong_attempt(v_user_id);
    if v_bump.just_locked then
      perform public._audit_log_insert(
        'mfa_lockout', v_user_id, v_user_id, v_org_id,
        jsonb_build_object('wrong_count', v_bump.wrong_count, 'locked_until', v_bump.locked_until, 'source', 'recovery_code')
      );
    end if;
    return jsonb_build_object('status', 'invalid');
  end if;

  update public.mfa_recovery_codes set used_at = now() where id = v_row.id;

  update public.auth_attempt_state
    set wrong_count = 0, locked_until = null, updated_at = now()
    where user_id = v_user_id;

  insert into public.mfa_reenrollment_required (user_id) values (v_user_id)
    on conflict (user_id) do nothing;

  perform public._audit_log_insert('recovery_code_used', v_user_id, v_user_id, v_org_id, '{}'::jsonb);

  return jsonb_build_object('status', 'ok', 'must_reenrol', true);
end;
$$;

-- ---------------------------------------------------------------------------
-- write_audit_log(): redefined as the guarded client-facing entry point.
-- service_role may write any row (trusted server-side callers); every other
-- caller must be proving the row describes their own action at aal2 inside
-- their own org. supabase/tests/090_audit_log.sql's existing assertion
-- (org_admin_a writing actor=self, target=another member, org=their own
-- active-membership org, at aal2) still satisfies this and is unchanged.
-- ---------------------------------------------------------------------------

create or replace function public.write_audit_log(
  p_event_type text,
  p_actor_user_id uuid,
  p_target_user_id uuid,
  p_org_id uuid,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if auth.role() = 'service_role' then
    perform public._audit_log_insert(p_event_type, p_actor_user_id, p_target_user_id, p_org_id, p_metadata);
    return;
  end if;

  if auth.uid() is null
     or p_actor_user_id is distinct from auth.uid()
     or not public.has_aal2()
     or p_org_id is distinct from public.current_org_id()
  then
    raise exception 'not authorized' using errcode = 'insufficient_privilege';
  end if;

  perform public._audit_log_insert(p_event_type, p_actor_user_id, p_target_user_id, p_org_id, p_metadata);
end;
$$;

revoke all on function public.write_audit_log(text, uuid, uuid, uuid, jsonb) from public, anon;
grant execute on function public.write_audit_log(text, uuid, uuid, uuid, jsonb) to authenticated, service_role;
