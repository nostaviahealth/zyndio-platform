-- Leo's review fix for step 2: public.write_audit_log() used to be callable
-- by any authenticated (or even anon, before an explicit revoke existed)
-- caller with fully caller-supplied actor/org, so anyone could forge audit
-- rows. Now: service_role may write any row; every other caller must prove
-- the row is about their own action (self, aal2, own active-membership
-- org). The internal writer, _audit_log_insert(), is never client-callable
-- at all. The existing hooks/recovery-code paths that write audit rows
-- internally (SECURITY DEFINER, now calling _audit_log_insert directly)
-- must keep working unchanged.
begin;
select no_plan();

-- ---------------------------------------------------------------------------
-- write_audit_log(): execute privileges
-- ---------------------------------------------------------------------------

select tests.authenticate_as_anon();
select throws_ok(
  $$ select public.write_audit_log('role_changed', '00000000-0000-0000-0000-0000000a0001', '00000000-0000-0000-0000-0000000a0002', '00000000-0000-0000-0000-00000000000a', '{}'::jsonb) $$,
  '42501', null,
  'anon cannot execute write_audit_log()'
);

-- ---------------------------------------------------------------------------
-- write_audit_log(): authenticated callers must be describing their own
-- action - org_admin_a ('...a0001', org A, active).
-- ---------------------------------------------------------------------------

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
select throws_ok(
  $$ select public.write_audit_log('role_changed', '00000000-0000-0000-0000-0000000a0002', '00000000-0000-0000-0000-0000000a0001', '00000000-0000-0000-0000-00000000000a', '{}'::jsonb) $$,
  '42501', null,
  'authenticated caller cannot assert an actor other than themselves - p_actor_user_id must equal auth.uid()'
);
select throws_ok(
  $$ select public.write_audit_log('role_changed', '00000000-0000-0000-0000-0000000a0001', '00000000-0000-0000-0000-0000000a0002', '00000000-0000-0000-0000-00000000000b', '{}'::jsonb) $$,
  '42501', null,
  'authenticated caller cannot assert an org they are not an active member of'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal1');
select throws_ok(
  $$ select public.write_audit_log('role_changed', '00000000-0000-0000-0000-0000000a0001', '00000000-0000-0000-0000-0000000a0002', '00000000-0000-0000-0000-00000000000a', '{}'::jsonb) $$,
  '42501', null,
  'write_audit_log() is rejected at aal1 even when actor and org are correct'
);

-- deactivated member: current_org_id() returns null for a deactivated
-- person, so the org check can never match. Use care_coordinator_a
-- ('...a0003') rather than org_admin_a, so this doesn't trip the
-- last-admin trigger.
reset role;
update public.org_members set status = 'deactivated' where user_id = '00000000-0000-0000-0000-0000000a0003';

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2');
select throws_ok(
  $$ select public.write_audit_log('role_changed', '00000000-0000-0000-0000-0000000a0003', '00000000-0000-0000-0000-0000000a0002', '00000000-0000-0000-0000-00000000000a', '{}'::jsonb) $$,
  '42501', null,
  'a deactivated member cannot write an audit row even as themselves - current_org_id() is null for them'
);

reset role;
update public.org_members set status = 'active' where user_id = '00000000-0000-0000-0000-0000000a0003';

-- the one call 090_audit_log.sql depends on must still pass unchanged: self,
-- own active org, aal2.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
select lives_ok(
  $$ select public.write_audit_log('role_changed', '00000000-0000-0000-0000-0000000a0001', '00000000-0000-0000-0000-0000000a0002', '00000000-0000-0000-0000-00000000000a', '{}'::jsonb) $$,
  'org_admin_a can still write an audit row about their own action, at aal2, in their own org'
);

-- ---------------------------------------------------------------------------
-- _audit_log_insert(): no client role may ever call the internal writer
-- directly, forged org or not.
-- ---------------------------------------------------------------------------

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
select throws_ok(
  $$ select public._audit_log_insert('role_changed', '00000000-0000-0000-0000-0000000a0001', '00000000-0000-0000-0000-0000000a0002', '00000000-0000-0000-0000-00000000000a', '{}'::jsonb) $$,
  '42501', null,
  'authenticated cannot execute _audit_log_insert() directly'
);

select tests.authenticate_as_anon();
select throws_ok(
  $$ select public._audit_log_insert('role_changed', '00000000-0000-0000-0000-0000000a0001', '00000000-0000-0000-0000-0000000a0002', '00000000-0000-0000-0000-00000000000a', '{}'::jsonb) $$,
  '42501', null,
  'anon cannot execute _audit_log_insert() directly'
);

reset role;

-- ---------------------------------------------------------------------------
-- the internal callers still write their own audit rows correctly through
-- _audit_log_insert() - one check each is enough, the full behaviour of
-- each path is already covered by 300_auth_hooks.sql / 310_recovery_codes.sql.
-- ---------------------------------------------------------------------------

-- read_only_a ('...a0004'): five wrong passwords -> lockout audit row.
\set lockout_uid '''00000000-0000-0000-0000-0000000a0004'''
select auth_hooks.password_verification_attempt(jsonb_build_object('user_id', :lockout_uid, 'valid', false));
select auth_hooks.password_verification_attempt(jsonb_build_object('user_id', :lockout_uid, 'valid', false));
select auth_hooks.password_verification_attempt(jsonb_build_object('user_id', :lockout_uid, 'valid', false));
select auth_hooks.password_verification_attempt(jsonb_build_object('user_id', :lockout_uid, 'valid', false));
select auth_hooks.password_verification_attempt(jsonb_build_object('user_id', :lockout_uid, 'valid', false));
select is(
  (select count(*)::int from public.audit_log where target_user_id = :lockout_uid::uuid and event_type = 'password_lockout'),
  1,
  'the password hook still writes a password_lockout audit row via _audit_log_insert() after the review fix'
);

-- physician_a ('...a0002'): a valid recovery code -> recovery_code_used
-- audit row.
insert into auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at)
values (
  '00000000-0000-0000-0000-0000000f0102', '00000000-0000-0000-0000-0000000a0002',
  'Authenticator', 'totp', 'verified', now(), now()
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
create temp table tmp_forgery_codes as
  select unnest(public.generate_recovery_codes()) as code;

-- B6 / L3: consume_recovery_code() now requires a recent (<=10 min)
-- password_verified_at, same window as the TOTP step.
reset role;
insert into public.auth_attempt_state (user_id, wrong_count, password_verified_at)
  values ('00000000-0000-0000-0000-0000000a0002', 0, now())
  on conflict (user_id) do update set password_verified_at = now();

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal1');
select is(
  ((select public.consume_recovery_code(code) from tmp_forgery_codes limit 1) ->> 'status'),
  'ok',
  'a valid recovery code is accepted'
);
reset role;

select is(
  (select count(*)::int from public.audit_log where target_user_id = '00000000-0000-0000-0000-0000000a0002' and event_type = 'recovery_code_used'),
  1,
  'consume_recovery_code() still writes a recovery_code_used audit row via _audit_log_insert() after the review fix'
);

select * from finish();
rollback;
