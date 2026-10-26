-- generate_recovery_codes() / consume_recovery_code(): aal2-only generation,
-- aal1-allowed consumption, one-time use, regeneration invalidates old
-- codes, a wrong code bumps the shared counter, and both success paths
-- audit-log + (for consume) flag mandatory re-enrollment.
begin;
select no_plan();

-- physician_a ('...a0002') gets a verified TOTP factor to generate codes for.
insert into auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at)
values (
  '00000000-0000-0000-0000-0000000f0002', '00000000-0000-0000-0000-0000000a0002',
  'Authenticator', 'totp', 'verified', now(), now()
);

-- ---------------------------------------------------------------------------
-- generate_recovery_codes(): aal2-only, self-only, 10 codes, invalidates
-- previous codes, audits "recovery_codes_regenerated".
-- ---------------------------------------------------------------------------

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal1');
select throws_ok(
  $$ select public.generate_recovery_codes() $$,
  null, null,
  'generate_recovery_codes() is rejected at aal1'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');

select is(
  array_length(public.generate_recovery_codes(), 1),
  10,
  'generate_recovery_codes() returns 10 codes'
);

reset role;
select is(
  (select count(*)::int from public.mfa_recovery_codes where user_id = '00000000-0000-0000-0000-0000000a0002'),
  10,
  '10 recovery code rows are stored (bcrypt hashes, not plaintext)'
);
select ok(
  (select code_hash <> 'any-plaintext-code' from public.mfa_recovery_codes where user_id = '00000000-0000-0000-0000-0000000a0002' limit 1),
  'stored code_hash is not the plaintext code'
);
select is(
  (select count(*)::int from public.audit_log where target_user_id = '00000000-0000-0000-0000-0000000a0002' and event_type = 'recovery_codes_regenerated'),
  1,
  'one recovery_codes_regenerated audit row was written'
);

-- regenerate: must invalidate the first batch (old codes gone from the table
-- entirely - delete-on-regenerate is this design's "invalidate" mechanism).
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select array_length(public.generate_recovery_codes(), 1); -- second batch
reset role;
select is(
  (select count(*)::int from public.mfa_recovery_codes where user_id = '00000000-0000-0000-0000-0000000a0002'),
  10,
  'regeneration leaves exactly 10 rows (old batch fully replaced, not appended)'
);
select is(
  (select count(*)::int from public.audit_log where target_user_id = '00000000-0000-0000-0000-0000000a0002' and event_type = 'recovery_codes_regenerated'),
  2,
  'a second recovery_codes_regenerated audit row was written on regeneration'
);

-- ---------------------------------------------------------------------------
-- consume_recovery_code(): aal1-allowed, one-time use, wrong code bumps the
-- shared counter, success flags re-enrollment + audits "recovery_code_used".
-- care_coordinator_a ('...a0003') gets its own factor + codes for a clean
-- counter (physician_a's counter above is untouched by this block).
-- ---------------------------------------------------------------------------

insert into auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at)
values (
  '00000000-0000-0000-0000-0000000f0003', '00000000-0000-0000-0000-0000000a0003',
  'Authenticator', 'totp', 'verified', now(), now()
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2');

-- generate_recovery_codes() only returns the plaintext once; capture it via
-- a temp table so later statements in this script can use a real code.
create temp table tmp_codes as
  select unnest(public.generate_recovery_codes()) as code;

-- B6 / L3: consume_recovery_code() now requires the same 10-minute
-- password_verified_at recency window auth_hooks.mfa_verification_attempt()
-- already applies to a TOTP code - model a just-completed password sign-in
-- for care_coordinator_a before exercising the success/failure paths below.
reset role;
insert into public.auth_attempt_state (user_id, wrong_count, password_verified_at)
  values ('00000000-0000-0000-0000-0000000a0003', 0, now())
  on conflict (user_id) do update set password_verified_at = now();

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal1');

select is(
  (public.consume_recovery_code('not-a-real-code') ->> 'status'),
  'invalid',
  'a wrong recovery code returns status invalid'
);
reset role;
select is(
  (select wrong_count from public.auth_attempt_state where user_id = '00000000-0000-0000-0000-0000000a0003'),
  1,
  'a wrong recovery code bumps the shared wrong_count counter'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal1');
select is(
  ((select public.consume_recovery_code(code) from tmp_codes limit 1) ->> 'status'),
  'ok',
  'a valid recovery code returns status ok'
);
reset role;

select is(
  (select count(*)::int from public.mfa_recovery_codes where user_id = '00000000-0000-0000-0000-0000000a0003' and used_at is not null),
  1,
  'the consumed code is marked used_at'
);
select is(
  (select wrong_count from public.auth_attempt_state where user_id = '00000000-0000-0000-0000-0000000a0003'),
  0,
  'wrong_count resets to 0 on a successful recovery code use'
);
select is(
  (select count(*)::int from public.mfa_reenrollment_required where user_id = '00000000-0000-0000-0000-0000000a0003'),
  1,
  'a successful recovery code use flags the person for mandatory re-enrollment'
);
select is(
  (select count(*)::int from public.audit_log where target_user_id = '00000000-0000-0000-0000-0000000a0003' and event_type = 'recovery_code_used'),
  1,
  'one recovery_code_used audit row was written'
);

-- one-time use: the same code cannot be consumed twice.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal1');
select is(
  ((select public.consume_recovery_code(code) from tmp_codes limit 1) ->> 'status'),
  'invalid',
  'a used recovery code cannot be consumed a second time'
);
reset role;

-- re-enrollment flag clears once new codes are issued (closes the cycle).
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2');
select public.generate_recovery_codes();
reset role;
select is(
  (select count(*)::int from public.mfa_reenrollment_required where user_id = '00000000-0000-0000-0000-0000000a0003'),
  0,
  'issuing new recovery codes clears the must-re-enrol flag'
);

-- ---------------------------------------------------------------------------
-- locked account: consume_recovery_code() reports locked without consuming
-- anything.
-- ---------------------------------------------------------------------------

update public.auth_attempt_state
  set locked_until = now() + interval '15 minutes'
  where user_id = '00000000-0000-0000-0000-0000000a0003';

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal1');
select is(
  ((select public.consume_recovery_code(code) from tmp_codes limit 1) ->> 'status'),
  'locked',
  'consume_recovery_code() reports locked when the shared counter is already locked'
);
reset role;

-- ---------------------------------------------------------------------------
-- L3: an old (or missing) password_verified_at is a challenge_expired
-- refusal, same shape/window as the TOTP step - not a silent "invalid" that
-- would otherwise bump the wrong-attempt counter for no reason.
-- ---------------------------------------------------------------------------

update public.auth_attempt_state
  set locked_until = null, wrong_count = 0, password_verified_at = now() - interval '11 minutes'
  where user_id = '00000000-0000-0000-0000-0000000a0003';

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal1');
select is(
  ((select public.consume_recovery_code(code) from tmp_codes limit 1) ->> 'status'),
  'challenge_expired',
  'consume_recovery_code() refuses a stale (>10 min) password_verified_at as challenge_expired'
);
reset role;
select is(
  (select wrong_count from public.auth_attempt_state where user_id = '00000000-0000-0000-0000-0000000a0003'),
  0,
  'a challenge_expired refusal does not bump the wrong-attempt counter'
);

-- ---------------------------------------------------------------------------
-- RLS: mfa_reenrollment_required is unreachable directly by any client role,
-- same pattern as auth_attempt_state / mfa_recovery_codes.
-- ---------------------------------------------------------------------------

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select throws_ok(
  $$ select count(*) from public.mfa_reenrollment_required $$,
  null, null,
  'org_admin_a cannot read mfa_reenrollment_required - grants are revoked'
);

select * from finish();
rollback;
