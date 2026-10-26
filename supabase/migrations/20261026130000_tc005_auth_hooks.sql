-- TC-005 step 2: Auth Hooks (password/MFA verification attempt), recovery
-- codes, and the server-side password blocklist. Builds on auth_attempt_state
-- / mfa_recovery_codes / audit_log from the step-1 schema migration; does not
-- edit any committed step-1 migration file.
--
-- Enumeration-safety design (plan Section B): a wrong password or wrong MFA
-- code NEVER returns "reject" from these hooks - GoTrue already returns an
-- identical generic error for wrong-password vs unknown-email on its own, and
-- our hook is never invoked at all for an unknown email. The only
-- distinguishable response is a CORRECT password on an ALREADY-locked
-- account, which is the one case Ava's copy explicitly permits
-- ("Sign-in is paused" only appears after a correct password).

-- Note: public.write_audit_log() still carries its step-1 default
-- grant-execute-to-PUBLIC (no explicit revoke exists on it). That means any
-- authenticated/anon caller can call it directly to forge audit rows, not
-- just the SECURITY DEFINER functions below. Tightening that is out of scope
-- for this step: supabase/tests/090_audit_log.sql (committed in step 1)
-- asserts org_admin_a CAN call write_audit_log() directly and relies on this
-- grant; revoking it would weaken/break that existing test. Flagged in
-- step2-summary.md as a leftover rather than silently fixed here.

-- ---------------------------------------------------------------------------
-- shared 5-strike / 15-minute lockout counter, used by the password hook,
-- the MFA hook, and consume_recovery_code() alike (one shared budget).
-- Internal-only: no role other than the owner ever calls this directly, so
-- no EXECUTE grant beyond the default owner access is needed; revoke PUBLIC
-- explicitly so that default never becomes a usable surface.
-- ---------------------------------------------------------------------------

create or replace function public.bump_wrong_attempt(p_user_id uuid)
returns table (wrong_count int, locked_until timestamptz, just_locked boolean)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_row public.auth_attempt_state;
  v_new_count int;
  v_new_locked timestamptz;
  v_just_locked boolean := false;
begin
  insert into public.auth_attempt_state (user_id, wrong_count)
  values (p_user_id, 0)
  on conflict (user_id) do nothing;

  select * into v_row from public.auth_attempt_state where user_id = p_user_id for update;

  if v_row.locked_until is not null and v_row.locked_until > now() then
    -- already locked: the lock stands as-is, further wrong attempts don't
    -- extend it (an attacker can't use this to keep an account locked
    -- indefinitely by re-trying every few minutes).
    return query select v_row.wrong_count, v_row.locked_until, false;
    return;
  end if;

  if v_row.locked_until is not null and v_row.locked_until <= now() then
    -- a prior lock just expired: this wrong attempt starts a fresh count.
    v_new_count := 1;
  else
    v_new_count := v_row.wrong_count + 1;
  end if;

  if v_new_count >= 5 then
    v_new_locked := now() + interval '15 minutes';
    v_just_locked := true;
  else
    v_new_locked := null;
  end if;

  update public.auth_attempt_state
    set wrong_count = v_new_count, locked_until = v_new_locked, updated_at = now()
    where user_id = p_user_id;

  return query select v_new_count, v_new_locked, v_just_locked;
end;
$$;

revoke all on function public.bump_wrong_attempt(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- auth_hooks schema + the two Postgres Auth Hooks.
-- ---------------------------------------------------------------------------

create schema auth_hooks;
revoke all on schema auth_hooks from public, anon, authenticated;
grant usage on schema auth_hooks to supabase_auth_admin;

-- Password Verification Attempt hook. Input per GoTrue's documented shape:
-- {"user_id": uuid, "valid": boolean}. Output: {"decision": "continue"} or
-- {"decision": "reject", "message": "..."}. Absent/omitted decision defaults
-- to continue on GoTrue's side, but every path below returns one explicitly.
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
    perform public.write_audit_log(
      'password_lockout', v_user_id, v_user_id, v_org_id,
      jsonb_build_object('wrong_count', v_bump.wrong_count, 'locked_until', v_bump.locked_until)
    );
  end if;

  return jsonb_build_object('decision', 'continue');
end;
$$;

revoke all on function auth_hooks.password_verification_attempt(jsonb) from public, anon, authenticated;
grant execute on function auth_hooks.password_verification_attempt(jsonb) to supabase_auth_admin;

-- MFA Verification Attempt hook. Input: {"factor_id": uuid, "factor_type":
-- "totp"|"phone", "user_id": uuid, "valid": boolean}. GoTrue has already
-- determined code correctness by the time this runs (that's what "valid"
-- means) - the hook's job is lockout + the 10-minute password-verified
-- window, not re-checking the code itself.
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
    perform public.write_audit_log(
      'mfa_lockout', v_user_id, v_user_id, v_org_id,
      jsonb_build_object('wrong_count', v_bump.wrong_count, 'locked_until', v_bump.locked_until)
    );
  end if;

  return jsonb_build_object('decision', 'continue');
end;
$$;

revoke all on function auth_hooks.mfa_verification_attempt(jsonb) from public, anon, authenticated;
grant execute on function auth_hooks.mfa_verification_attempt(jsonb) to supabase_auth_admin;

-- Belt-and-braces per the plan ("grant supabase_auth_admin what it needs on
-- auth_attempt_state"): the hooks above are SECURITY DEFINER so they don't
-- strictly need table-level grants to run, but give supabase_auth_admin
-- direct access too in case a future hook is added as a plain (non-definer)
-- function.
grant select, insert, update on public.auth_attempt_state to supabase_auth_admin;

-- ---------------------------------------------------------------------------
-- recovery codes (OVERRIDES #3 + Henry's answer #10): a valid recovery code
-- never grants aal2 directly (a recovery-code session stays aal1, which
-- would leave staff RLS closed to the person). Instead: consume_recovery_code
-- is allowed at aal1, shares the same 5/15 counter, is one-time use, and on
-- success flags the person for mandatory immediate re-enrollment (next step:
-- 02-2fa-setup scan -> verify -> new recovery codes). The actual TOTP factor
-- removal is step 3's service-role Edge Function; this table is the flag it
-- reads (and clears once generate_recovery_codes() issues fresh codes,
-- completing the re-enrollment cycle).
-- ---------------------------------------------------------------------------

create table public.mfa_reenrollment_required (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.mfa_reenrollment_required enable row level security;
alter table public.mfa_reenrollment_required force row level security;
revoke all on public.mfa_reenrollment_required from anon, authenticated;

-- Only callable at aal2, by the signed-in user for themselves (auth.uid(),
-- no target-user parameter at all). Invalidates every previous code for the
-- user and returns the 10 new plaintext codes exactly once - only the bcrypt
-- hashes are ever stored.
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

  perform public.write_audit_log(
    'recovery_codes_regenerated', v_user_id, v_user_id,
    (select org_id from public.org_members where user_id = v_user_id),
    '{}'::jsonb
  );

  return v_codes;
end;
$$;

revoke all on function public.generate_recovery_codes() from public, anon, authenticated;
grant execute on function public.generate_recovery_codes() to authenticated;

-- Allowed at aal1 (the person is mid-challenge, not yet aal2). Shares
-- bump_wrong_attempt with the password/MFA hooks. One-time use: the matched
-- row is marked used_at immediately so it can't be replayed.
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
      perform public.write_audit_log(
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

  perform public.write_audit_log('recovery_code_used', v_user_id, v_user_id, v_org_id, '{}'::jsonb);

  return jsonb_build_object('status', 'ok', 'must_reenrol', true);
end;
$$;

revoke all on function public.consume_recovery_code(text) from public, anon, authenticated;
grant execute on function public.consume_recovery_code(text) to authenticated;

-- ---------------------------------------------------------------------------
-- password blocklist (OVERRIDES #13): server-side check used later by the
-- invite-acceptance / password-set flow. Local GoTrue's leaked-password
-- (HIBP) check isn't relied on (plan risk #5) - this denylist stands in for
-- it. Small, fictional-safe, lowercase-normalized list of common passwords.
-- ---------------------------------------------------------------------------

create table public.password_blocklist (
  password text primary key
);

alter table public.password_blocklist enable row level security;
alter table public.password_blocklist force row level security;
revoke all on public.password_blocklist from anon, authenticated;

insert into public.password_blocklist (password) values
  ('password1234'),
  ('qwertyuiop12'),
  ('letmein12345'),
  ('welcome12345'),
  ('admin1234567'),
  ('iloveyou1234'),
  ('monkey1234567'),
  ('dragon1234567'),
  ('sunshine12345'),
  ('princess12345'),
  ('football12345'),
  ('baseball12345'),
  ('trustno112345'),
  ('123456789012'),
  ('abcdefghijkl');

create or replace function public.password_is_blocked(p_password text)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1 from public.password_blocklist where password = lower(p_password)
  );
$$;

revoke all on function public.password_is_blocked(text) from public;
grant execute on function public.password_is_blocked(text) to anon, authenticated, service_role;
