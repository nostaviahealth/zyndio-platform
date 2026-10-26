-- auth_hooks.password_verification_attempt / mfa_verification_attempt:
-- lockout at 5, unlock after 15 min (simulated by moving locked_until back
-- as the table owner), the 10-minute password-verified window, and the
-- enumeration-safety invariant that a wrong password/code never "reject"s.
-- Execute privileges: only supabase_auth_admin may call either hook.
begin;
select no_plan();

-- physician_a ('...a0002') is a fresh actor with no auth_attempt_state row
-- yet - the hooks create one on first call.
\set uid '''00000000-0000-0000-0000-0000000a0002'''

-- ---------------------------------------------------------------------------
-- execute privileges
-- ---------------------------------------------------------------------------

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select throws_ok(
  $$ select auth_hooks.password_verification_attempt('{"user_id":"00000000-0000-0000-0000-0000000a0002","valid":false}'::jsonb) $$,
  null, null,
  'authenticated cannot call auth_hooks.password_verification_attempt - execute is supabase_auth_admin only'
);
select throws_ok(
  $$ select auth_hooks.mfa_verification_attempt('{"user_id":"00000000-0000-0000-0000-0000000a0002","valid":false}'::jsonb) $$,
  null, null,
  'authenticated cannot call auth_hooks.mfa_verification_attempt - execute is supabase_auth_admin only'
);

select tests.authenticate_as_anon();
select throws_ok(
  $$ select auth_hooks.password_verification_attempt('{"user_id":"00000000-0000-0000-0000-0000000a0002","valid":false}'::jsonb) $$,
  null, null,
  'anon cannot call auth_hooks.password_verification_attempt'
);

reset role;

-- ---------------------------------------------------------------------------
-- password hook: wrong password always "continue", lockout at the 5th
-- strike, and a correct password while locked is the one "reject" case.
-- ---------------------------------------------------------------------------

select is(
  (auth_hooks.password_verification_attempt(jsonb_build_object('user_id', :uid, 'valid', false)) ->> 'decision'),
  'continue',
  'wrong password (1st) returns continue'
);
select is(
  (select wrong_count from public.auth_attempt_state where user_id = :uid::uuid),
  1,
  'wrong_count is 1 after one wrong password'
);

select auth_hooks.password_verification_attempt(jsonb_build_object('user_id', :uid, 'valid', false));
select auth_hooks.password_verification_attempt(jsonb_build_object('user_id', :uid, 'valid', false));
select auth_hooks.password_verification_attempt(jsonb_build_object('user_id', :uid, 'valid', false));

select is(
  (auth_hooks.password_verification_attempt(jsonb_build_object('user_id', :uid, 'valid', false)) ->> 'decision'),
  'continue',
  'the 5th wrong password still returns continue (enumeration-safety: never reject on a wrong password)'
);
select is(
  (select wrong_count from public.auth_attempt_state where user_id = :uid::uuid),
  5,
  'wrong_count is 5 after five wrong passwords'
);
select ok(
  (select locked_until > now() from public.auth_attempt_state where user_id = :uid::uuid),
  'account is locked (locked_until in the future) after the 5th wrong password'
);

select is(
  (auth_hooks.password_verification_attempt(jsonb_build_object('user_id', :uid, 'valid', true)) ->> 'decision'),
  'reject',
  'a CORRECT password on a locked account is rejected'
);
select is(
  (auth_hooks.password_verification_attempt(jsonb_build_object('user_id', :uid, 'valid', true)) ->> 'message'),
  'locked',
  'the reject message is "locked"'
);

-- audit row for the lockout
select is(
  (select count(*)::int from public.audit_log where target_user_id = :uid::uuid and event_type = 'password_lockout'),
  1,
  'exactly one password_lockout audit row was written'
);

-- simulate 15 minutes passing, as the table owner (pgTAP runs as owner
-- inside this transaction before any authenticate_as() switch).
update public.auth_attempt_state set locked_until = now() - interval '1 second' where user_id = :uid::uuid;

select is(
  (auth_hooks.password_verification_attempt(jsonb_build_object('user_id', :uid, 'valid', true)) ->> 'decision'),
  'continue',
  'a correct password after the lock window has elapsed returns continue'
);
select is(
  (select wrong_count from public.auth_attempt_state where user_id = :uid::uuid),
  0,
  'wrong_count resets to 0 on a successful password verification'
);
select ok(
  (select locked_until is null from public.auth_attempt_state where user_id = :uid::uuid),
  'locked_until is cleared on a successful password verification'
);
select ok(
  (select password_verified_at is not null from public.auth_attempt_state where user_id = :uid::uuid),
  'password_verified_at is set on a successful password verification'
);

-- ---------------------------------------------------------------------------
-- MFA hook: challenge_expired, locked, wrong-code counter, 10-minute window.
-- ---------------------------------------------------------------------------

-- care_coordinator_a ('...a0003'): password not yet verified at all.
\set uid2 '''00000000-0000-0000-0000-0000000a0003'''

select is(
  (auth_hooks.mfa_verification_attempt(jsonb_build_object('user_id', :uid2, 'valid', true)) ->> 'message'),
  'challenge_expired',
  'MFA challenge is rejected as expired when password_verified_at is null'
);

select auth_hooks.password_verification_attempt(jsonb_build_object('user_id', :uid2, 'valid', true));
update public.auth_attempt_state set password_verified_at = now() - interval '11 minutes' where user_id = :uid2::uuid;

select is(
  (auth_hooks.mfa_verification_attempt(jsonb_build_object('user_id', :uid2, 'valid', true)) ->> 'message'),
  'challenge_expired',
  'MFA challenge is rejected as expired when password_verified_at is older than 10 minutes'
);

update public.auth_attempt_state set password_verified_at = now() where user_id = :uid2::uuid;

select is(
  (auth_hooks.mfa_verification_attempt(jsonb_build_object('user_id', :uid2, 'valid', false)) ->> 'decision'),
  'continue',
  'a wrong MFA code within the window still returns continue (not reject)'
);
select is(
  (select wrong_count from public.auth_attempt_state where user_id = :uid2::uuid),
  1,
  'wrong_count increments on a wrong MFA code'
);

update public.auth_attempt_state set wrong_count = 4 where user_id = :uid2::uuid;
select auth_hooks.mfa_verification_attempt(jsonb_build_object('user_id', :uid2, 'valid', false));

select ok(
  (select locked_until > now() from public.auth_attempt_state where user_id = :uid2::uuid),
  'account locks on the 5th wrong MFA code (same shared counter as password)'
);
select is(
  (select count(*)::int from public.audit_log where target_user_id = :uid2::uuid and event_type = 'mfa_lockout'),
  1,
  'exactly one mfa_lockout audit row was written'
);
select is(
  (auth_hooks.mfa_verification_attempt(jsonb_build_object('user_id', :uid2, 'valid', true)) ->> 'message'),
  'locked',
  'MFA is rejected as locked once locked, even with a correct code'
);

select * from finish();
rollback;
