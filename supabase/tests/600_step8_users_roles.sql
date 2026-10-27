-- TC-005 step 8: list_org_members() and the request_mfa_reset() own-row guard.
begin;
select no_plan();

-- list_org_members(): org_admin_a sees exactly org A's 4 members, with email.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select is(
  (select count(*)::int from public.list_org_members()),
  4,
  'list_org_members: org_admin_a sees exactly org A''s 4 members'
);
select is(
  (select email from public.list_org_members() where user_id = '00000000-0000-0000-0000-0000000a0002'),
  'physician-a@example.test',
  'list_org_members: returns the member''s email from auth.users'
);

-- Non-admin and aal1 are both refused.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select throws_ok(
  $$ select * from public.list_org_members() $$,
  '42501', null,
  'list_org_members: a non-admin is refused'
);
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal1'); -- org_admin_a at aal1
select throws_ok(
  $$ select * from public.list_org_members() $$,
  '42501', null,
  'list_org_members: an aal1 admin is refused'
);

-- request_mfa_reset: org_admin_a cannot request a reset for themselves.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select throws_ok(
  $$ select public.request_mfa_reset('00000000-0000-0000-0000-0000000a0001') $$,
  '42501', null,
  'request_mfa_reset: org_admin_a cannot request a reset of their own 2FA'
);

-- Positive: org_admin_a requests a reset for someone else - audited, no
-- change to the target's row (resets nothing by itself).
select lives_ok(
  $$ select public.request_mfa_reset('00000000-0000-0000-0000-0000000a0002') $$,
  'request_mfa_reset: org_admin_a can request a reset for physician_a'
);
reset role;
select set_config('request.jwt.claims', '', true);
select is(
  (select count(*)::int from public.audit_log where event_type = 'mfa_reset_requested' and target_user_id = '00000000-0000-0000-0000-0000000a0002' and actor_user_id = '00000000-0000-0000-0000-0000000a0001'),
  1,
  'request_mfa_reset: writes exactly one mfa_reset_requested audit row'
);

-- TC-011 Ava request-2fa-reset dialog: optional p_reason is carried through
-- to the audit row's metadata (a Zyndio admin reading the request sees it).
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select lives_ok(
  $$ select public.request_mfa_reset('00000000-0000-0000-0000-0000000a0003', 'Got a new phone and lost the authenticator.') $$,
  'request_mfa_reset: accepts an optional reason'
);
reset role;
select set_config('request.jwt.claims', '', true);
select is(
  (select metadata ->> 'reason' from public.audit_log where event_type = 'mfa_reset_requested' and target_user_id = '00000000-0000-0000-0000-0000000a0003'),
  'Got a new phone and lost the authenticator.',
  'request_mfa_reset: the reason is stored in the audit row metadata'
);
select is(
  (select metadata ->> 'reason' from public.audit_log where event_type = 'mfa_reset_requested' and target_user_id = '00000000-0000-0000-0000-0000000a0002'),
  null,
  'request_mfa_reset: no reason was given is stored as null, not the literal string'
);

select * from finish();
rollback;
