-- APP-01: invite-based sign-in with an emailed one-time code.
--   * issue/redeem_patient_login_code, issue_patient_invite and
--     patient_self_signup_open are service_role only;
--   * only patient accounts get a code (never staff / platform admin);
--   * codes: wrong -> invalid, right -> ok once, reuse/expiry -> expired,
--     5 wrong -> locked for 15 min, and a re-issue can't clear the lock;
--   * an unknown email behaves exactly like a known one (enumeration);
--   * invites: one open invite per patient, accepted on first sign-in,
--     visible to own-clinic staff only;
--   * self sign-up is closed unless the org turns it on;
--   * the emailed code is scrubbed from notification_outbox like a token.
begin;
select no_plan();

-- ---------------------------------------------------------------------------
-- privileges
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1'); -- patient_a1
select throws_ok($$ select public.issue_patient_login_code('patient-a1@example.test', '123456', 600) $$,
  '42501', null, 'a patient cannot issue a sign-in code directly');
select throws_ok($$ select public.redeem_patient_login_code('patient-a1@example.test', '123456', 5, 900) $$,
  '42501', null, 'a patient cannot redeem a code directly (the Edge Function must front it)');
select throws_ok($$ select public.issue_patient_invite('00000000-0000-0000-0000-0000000a1001', null, 'staff') $$,
  '42501', null, 'a patient cannot issue an invite');
select throws_ok($$ select count(*) from public.patient_login_codes $$,
  '42501', null, 'a patient cannot read patient_login_codes');
reset role;

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2'); -- care_coordinator_a
select throws_ok($$ select public.issue_patient_invite('00000000-0000-0000-0000-0000000a1001', null, 'staff') $$,
  '42501', null, 'staff cannot call issue_patient_invite directly (create-patient does, as service_role)');
select throws_ok($$ select public.patient_self_signup_open('00000000-0000-0000-0000-00000000000a') $$,
  '42501', null, 'staff cannot call patient_self_signup_open directly');
reset role;

select tests.authenticate_as_anon();
select throws_ok($$ select public.issue_patient_login_code('patient-a1@example.test', '123456', 600) $$,
  '42501', null, 'anon cannot issue a sign-in code directly');
select throws_ok($$ select public.redeem_patient_login_code('patient-a1@example.test', '123456', 5, 900) $$,
  '42501', null, 'anon cannot redeem a code directly');
reset role;

-- ---------------------------------------------------------------------------
-- who gets a code
-- ---------------------------------------------------------------------------
select tests.authenticate_as_service_role();
select is(public.issue_patient_login_code('patient-a1@example.test', '111111', 600),
  '00000000-0000-0000-0000-0000000a1001'::uuid,
  'a staff-created patient is eligible: the code goes to their account');
select is(public.issue_patient_login_code('  Patient-A1@Example.TEST ', '111111', 600),
  '00000000-0000-0000-0000-0000000a1001'::uuid,
  'email match is case- and whitespace-insensitive');
select is(public.issue_patient_login_code('physician-a@example.test', '222222', 600), null::uuid,
  'a staff account never gets a patient sign-in code');
select is(public.issue_patient_login_code('zyndio-admin@example.test', '222222', 600), null::uuid,
  'a platform admin never gets a patient sign-in code');
select is(public.issue_patient_login_code('spare-xorg@example.test', '222222', 600), null::uuid,
  'an auth user with no patients row and no self-signup marker gets no code');
select is(public.issue_patient_login_code('nobody-app01@example.test', '222222', 600), null::uuid,
  'an unknown email gets no code');
select is((select count(*)::int from public.patient_login_codes
            where email_hash = public._patient_email_hash('nobody-app01@example.test')), 1,
  'an unknown email still gets a (never-sent) code row, so it behaves like a known one');
select throws_ok($$ select public.issue_patient_login_code('patient-a1@example.test', '12ab56', 600) $$,
  '22023', null, 'a code must be exactly 6 digits');

-- ---------------------------------------------------------------------------
-- redeem: invalid / ok / single use / expiry
-- ---------------------------------------------------------------------------
select is(public.redeem_patient_login_code('patient-a1@example.test', '999999', 5, 900) ->> 'result', 'invalid',
  'a wrong code is invalid');
select is(public.redeem_patient_login_code('patient-a1@example.test', '111111', 5, 900) ->> 'result', 'ok',
  'the right code signs the patient in');
select is(public.issue_patient_login_code('patient-a1@example.test', '333333', 600),
  '00000000-0000-0000-0000-0000000a1001'::uuid, 'issue a fresh code');
select is(public.redeem_patient_login_code('patient-a1@example.test', '333333', 5, 900) ->> 'user_id',
  '00000000-0000-0000-0000-0000000a1001',
  'ok returns the patient''s user id for the Edge Function to mint a session for');
select is(public.redeem_patient_login_code('patient-a1@example.test', '333333', 5, 900) ->> 'result', 'expired',
  'a code works once: the same code again is spent');

select public.issue_patient_login_code('patient-a1@example.test', '444444', 600);
update public.patient_login_codes set expires_at = now() - interval '1 second'
  where email_hash = public._patient_email_hash('patient-a1@example.test');
select is(public.redeem_patient_login_code('patient-a1@example.test', '444444', 5, 900) ->> 'result', 'expired',
  'a code past its 10 minutes is expired, even when it is right');

select is(public.redeem_patient_login_code('physician-a@example.test', '222222', 5, 900) ->> 'result', 'invalid',
  'a staff email''s code is never redeemable, even with the exact code');
select is(public.redeem_patient_login_code('never-requested@example.test', '123456', 5, 900) ->> 'result', 'invalid',
  'an email that never requested a code is invalid');

-- ---------------------------------------------------------------------------
-- lockout: 5 wrong tries, then locked; a re-issue keeps the lock
-- ---------------------------------------------------------------------------
select public.issue_patient_login_code('patient-a1@example.test', '555555', 600);
select is(public.redeem_patient_login_code('patient-a1@example.test', '000001', 5, 900) ->> 'result', 'invalid', 'wrong try 1');
select is(public.redeem_patient_login_code('patient-a1@example.test', '000002', 5, 900) ->> 'result', 'invalid', 'wrong try 2');
select is(public.redeem_patient_login_code('patient-a1@example.test', '000003', 5, 900) ->> 'result', 'invalid', 'wrong try 3');
select is(public.redeem_patient_login_code('patient-a1@example.test', '000004', 5, 900) ->> 'result', 'invalid', 'wrong try 4');
select is(public.redeem_patient_login_code('patient-a1@example.test', '000005', 5, 900) ->> 'result', 'locked',
  'the 5th wrong try locks the email');
select is(public.redeem_patient_login_code('patient-a1@example.test', '555555', 5, 900) ->> 'result', 'locked',
  'while locked, even the right code is refused');
select ok((public.redeem_patient_login_code('patient-a1@example.test', '555555', 5, 900) ->> 'retry_after_seconds')::int
            between 1 and 900,
  'locked reports the real time left');
select public.issue_patient_login_code('patient-a1@example.test', '666666', 600);
select is(public.redeem_patient_login_code('patient-a1@example.test', '666666', 5, 900) ->> 'result', 'locked',
  'asking for a new code does not clear the lock');
update public.patient_login_codes set locked_until = now() - interval '1 second'
  where email_hash = public._patient_email_hash('patient-a1@example.test');
select public.issue_patient_login_code('patient-a1@example.test', '777777', 600);
select is(public.redeem_patient_login_code('patient-a1@example.test', '777777', 5, 900) ->> 'result', 'ok',
  'after the lock ends, a new code works');

-- Same lockout for an unknown email (no enumeration via lockout behaviour).
select public.issue_patient_login_code('nobody-lock@example.test', '123123', 600);
select is(public.redeem_patient_login_code('nobody-lock@example.test', '000001', 5, 900) ->> 'result', 'invalid', 'unknown: wrong 1');
select is(public.redeem_patient_login_code('nobody-lock@example.test', '000002', 5, 900) ->> 'result', 'invalid', 'unknown: wrong 2');
select is(public.redeem_patient_login_code('nobody-lock@example.test', '000003', 5, 900) ->> 'result', 'invalid', 'unknown: wrong 3');
select is(public.redeem_patient_login_code('nobody-lock@example.test', '000004', 5, 900) ->> 'result', 'invalid', 'unknown: wrong 4');
select is(public.redeem_patient_login_code('nobody-lock@example.test', '000005', 5, 900) ->> 'result', 'locked',
  'an unknown email locks after 5 wrong tries, same as a real one');
select is(public.redeem_patient_login_code('nobody-lock@example.test', '123123', 5, 900) ->> 'result', 'locked',
  'and stays locked, even for its own (never-sent) code');

-- ---------------------------------------------------------------------------
-- invites
-- ---------------------------------------------------------------------------
select ok((public.issue_patient_invite('00000000-0000-0000-0000-0000000a1001',
                                       '00000000-0000-0000-0000-0000000a0003', 'staff') ->> 'invite_id') is not null,
  'issue_patient_invite creates an invite for a staff-created patient');
select is((public.issue_patient_invite('00000000-0000-0000-0000-0000000a1001', null, 'api') ->> 'email'),
  'patient-a1@example.test', 'the invite goes to the patient''s account email (api source)');
select is((select count(*)::int from public.patient_invites
            where patient_id = '00000000-0000-0000-0000-0000000a1001'
              and accepted_at is null and revoked_at is null), 1,
  're-inviting revokes the earlier open invite: one open invite per patient');
select is((select count(*)::int from public.patient_invites
            where patient_id = '00000000-0000-0000-0000-0000000a1001' and revoked_at is not null), 1,
  'the earlier invite is kept, marked revoked');
select throws_ok($$ select public.issue_patient_invite('00000000-0000-0000-0000-0000000a0002', null, 'staff') $$,
  'P0002', null, 'a staff account (no patients row) cannot be invited as a patient');
select throws_ok($$ select public.issue_patient_invite('00000000-0000-0000-0000-0000000a1001', null, 'email') $$,
  '22023', null, 'invite source must be staff or api');

select public.issue_patient_login_code('patient-a1@example.test', '818181', 600);
select is(public.redeem_patient_login_code('patient-a1@example.test', '818181', 5, 900) ->> 'result', 'ok',
  'invited patient signs in with the emailed code');
select ok((select accepted_at is not null from public.patient_invites
            where patient_id = '00000000-0000-0000-0000-0000000a1001' and revoked_at is null),
  'the first successful sign-in accepts the open invite');
select is((select count(*)::int from public.audit_log
            where event_type = 'patient_invite_accepted'
              and target_user_id = '00000000-0000-0000-0000-0000000a1001'), 1,
  'invite acceptance is audited');
reset role;

-- staff of the patient's clinic can see invite status; nobody else can.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2'); -- care_coordinator_a
select is((select count(*)::int from public.patient_invites), 2, 'care_coordinator_a sees own-clinic invites');
select throws_ok($$ insert into public.patient_invites (org_id, patient_id, email, source)
                     values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'x@example.test', 'staff') $$,
  '42501', null, 'staff cannot write invites through the API');
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal1');
select is((select count(*)::int from public.patient_invites), 0, 'staff at aal1 see no invites');
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2'); -- physician_b
select is((select count(*)::int from public.patient_invites), 0, 'other-clinic staff see no invites');
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1'); -- patient_a1
select is((select count(*)::int from public.patient_invites), 0, 'patients do not read the invites table');
reset role;

-- ---------------------------------------------------------------------------
-- self sign-up org setting
-- ---------------------------------------------------------------------------
select tests.authenticate_as_service_role();
select is(public.patient_self_signup_open('00000000-0000-0000-0000-00000000000a'), false,
  'self sign-up is closed by default');
select is(public.patient_self_signup_open('00000000-0000-0000-0000-0000000000ff'), false,
  'an unknown org reads as closed');
select is(public.patient_self_signup_open(null), false, 'no org configured reads as closed');
reset role;
update public.organizations set patient_self_signup_enabled = true
  where id = '00000000-0000-0000-0000-00000000000a';
select tests.authenticate_as_service_role();
select is(public.patient_self_signup_open('00000000-0000-0000-0000-00000000000a'), true,
  'an org can turn self sign-up on');
reset role;

-- ---------------------------------------------------------------------------
-- emailed code is scrubbed from notification_outbox like the other tokens
-- ---------------------------------------------------------------------------
select is(public._notification_outbox_scrub_payload('patient_login_code', '{"email":"x@example.test","token":"123456"}'::jsonb) -> 'token',
  'null'::jsonb, 'the scrub nulls a patient_login_code token');
insert into public.notification_outbox (type, payload, created_at)
  values ('patient_login_code', '{"token":"654321"}', now() - interval '16 minutes');
select ok(public._scrub_stale_notification_outbox() >= 1, 'stale-scrub sweeps patient_login_code rows');
select is((select payload -> 'token' from public.notification_outbox
            where type = 'patient_login_code' order by created_at limit 1),
  'null'::jsonb, 'a 16-minute-old code row has no code left');

select * from finish();
rollback;
