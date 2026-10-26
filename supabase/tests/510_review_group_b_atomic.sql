-- B3 (M4): finalize_deactivation/finalize_mfa_reset are the one-transaction
-- replacements for deactivate-user/reset-mfa's previously separate (and, for
-- sign-out/audit failures, silently swallowed) steps. service_role only;
-- a failure partway through must roll back everything, not leave a
-- half-applied state.
begin;
select no_plan();

select function_returns('public', 'finalize_deactivation', array['uuid', 'uuid', 'uuid'], 'uuid', 'finalize_deactivation(uuid,uuid,uuid) returns uuid (the new notification_outbox row id)');
select function_returns('public', 'finalize_mfa_reset', array['uuid', 'uuid', 'uuid'], 'uuid', 'finalize_mfa_reset(uuid,uuid,uuid) returns uuid (the new notification_outbox row id)');

-- Neither RPC is callable by an ordinary authenticated user, even an admin
-- of their own org, nor by anon - only the Edge Functions (via service_role)
-- may call them.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select throws_ok(
  $$ select public.finalize_deactivation('00000000-0000-0000-0000-0000000a0004'::uuid, '00000000-0000-0000-0000-0000000a0001'::uuid, '00000000-0000-0000-0000-00000000000a'::uuid) $$,
  '42501', null,
  'an authenticated org_admin cannot execute finalize_deactivation directly - service_role only'
);
select throws_ok(
  $$ select public.finalize_mfa_reset('00000000-0000-0000-0000-0000000a0003'::uuid, '00000000-0000-0000-0000-0000000a0001'::uuid, '00000000-0000-0000-0000-00000000000a'::uuid) $$,
  '42501', null,
  'an authenticated org_admin cannot execute finalize_mfa_reset directly - service_role only'
);

select tests.authenticate_as_anon();
select throws_ok(
  $$ select public.finalize_deactivation('00000000-0000-0000-0000-0000000a0004'::uuid, '00000000-0000-0000-0000-0000000a0001'::uuid, '00000000-0000-0000-0000-00000000000a'::uuid) $$,
  '42501', null,
  'anon cannot execute finalize_deactivation'
);
reset role;

-- Failure case: a target that is not actually in the given org raises
-- (P0002) and the whole transaction rolls back - no audit row, no outbox
-- row, no invite touched. This is the atomicity finding (M4): the old code
-- could leave an audit-less deactivation behind; this cannot, because it is
-- all one transaction and failures propagate instead of being swallowed.
select tests.authenticate_as_service_role();
select is((select count(*)::int from public.audit_log where event_type = 'user_deactivated' and target_user_id = '00000000-0000-0000-0000-0000000b1001'), 0, 'precondition: no prior user_deactivated audit row for patient-b1''s id');
select throws_ok(
  $$ select public.finalize_deactivation('00000000-0000-0000-0000-0000000b1001'::uuid, '00000000-0000-0000-0000-0000000a0001'::uuid, '00000000-0000-0000-0000-00000000000a'::uuid) $$,
  'P0002', null,  -- "member not found in organization" (finalize_deactivation), not a permission error
  'finalize_deactivation on a user not in the given org raises, instead of silently doing nothing'
);
select is(
  (select count(*)::int from public.audit_log where event_type = 'user_deactivated' and target_user_id = '00000000-0000-0000-0000-0000000b1001'),
  0,
  'a failed finalize_deactivation call writes no audit row (atomic, not partial)'
);
reset role;

-- Success case: one call does status + invite revoke + sign-out + audit +
-- outbox together.
insert into auth.sessions (id, user_id, created_at, updated_at)
values ('00000000-0000-0000-0000-0000000d0002', '00000000-0000-0000-0000-0000000a0004', now(), now());

select tests.authenticate_as_service_role();
select lives_ok(
  $$ select public.finalize_deactivation('00000000-0000-0000-0000-0000000a0004'::uuid, '00000000-0000-0000-0000-0000000a0001'::uuid, '00000000-0000-0000-0000-00000000000a'::uuid) $$,
  'finalize_deactivation succeeds for a real org member'
);
reset role;

select is(
  (select status from public.org_members where user_id = '00000000-0000-0000-0000-0000000a0004'),
  'deactivated',
  'finalize_deactivation flips status to deactivated'
);
select is(
  (select count(*)::int from auth.sessions where user_id = '00000000-0000-0000-0000-0000000a0004'),
  0,
  'finalize_deactivation force-signs-out the target (session deleted)'
);
select is(
  (select count(*)::int from public.audit_log where event_type = 'user_deactivated' and target_user_id = '00000000-0000-0000-0000-0000000a0004'),
  1,
  'finalize_deactivation writes exactly one user_deactivated audit row'
);
select is(
  (select count(*)::int from public.notification_outbox where type = 'user_deactivated' and user_id = '00000000-0000-0000-0000-0000000a0004'),
  1,
  'finalize_deactivation writes exactly one user_deactivated outbox row'
);

-- Last-admin protection still applies inside the RPC (P0001, not swallowed).
select tests.authenticate_as_service_role();
select throws_ok(
  $$ select public.finalize_deactivation('00000000-0000-0000-0000-0000000a0001'::uuid, '00000000-0000-0000-0000-0000000a0001'::uuid, '00000000-0000-0000-0000-00000000000a'::uuid) $$,
  'P0001', null,  -- enforce_last_admin trigger, not a permission error
  'finalize_deactivation still refuses to deactivate the last active org admin'
);
reset role;

-- finalize_mfa_reset: flag + sign-out + audit + outbox together.
insert into auth.sessions (id, user_id, created_at, updated_at)
values ('00000000-0000-0000-0000-0000000d0003', '00000000-0000-0000-0000-0000000a0003', now(), now());

select tests.authenticate_as_service_role();
select lives_ok(
  $$ select public.finalize_mfa_reset('00000000-0000-0000-0000-0000000a0003'::uuid, '00000000-0000-0000-0000-0000000a0001'::uuid, '00000000-0000-0000-0000-00000000000a'::uuid) $$,
  'finalize_mfa_reset succeeds for a real org member'
);
reset role;

select is(
  (select count(*)::int from public.mfa_reenrollment_required where user_id = '00000000-0000-0000-0000-0000000a0003'),
  1,
  'finalize_mfa_reset flags the target for mandatory re-enrollment'
);
select is(
  (select count(*)::int from auth.sessions where user_id = '00000000-0000-0000-0000-0000000a0003'),
  0,
  'finalize_mfa_reset force-signs-out the target'
);
select is(
  (select count(*)::int from public.audit_log where event_type = 'mfa_reset' and target_user_id = '00000000-0000-0000-0000-0000000a0003'),
  1,
  'finalize_mfa_reset writes exactly one mfa_reset audit row'
);
select is(
  (select count(*)::int from public.notification_outbox where type = 'mfa_reset' and user_id = '00000000-0000-0000-0000-0000000a0003'),
  1,
  'finalize_mfa_reset writes exactly one mfa_reset outbox row'
);

select * from finish();
rollback;
