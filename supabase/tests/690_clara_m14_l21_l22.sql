-- Clara M14 (backfill clinic_provisioned links), L21 (scrub OTP from outbox),
-- L22 (refuse cross-clinic re-bind). Fictional data only.
begin;
select no_plan();

-- ---------------------------------------------------------------------------
-- M14: pre-M12 clinic-provisioned patients (org_id set, no link, no
-- self-signup marker) get backfilled an active clinic_provisioned link.
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', '', true);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000d1401',
  'authenticated', 'authenticated', 'm14.legacy@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb, now(), now()
);

-- Simulates a pre-M12 clinic-provisioned patient: org_id set, no link row,
-- no self-signup marker (as create_patient_record would have left things
-- before the H-M3/M12 migration started inserting a link too).
insert into public.patients (id, org_id, display_name, mrn) values (
  '00000000-0000-0000-0000-0000000d1401',
  '00000000-0000-0000-0000-00000000000a',
  'M14 Legacy Patient',
  'MRN-M14'
);

insert into public.lab_reports (id, org_id, patient_id, report_type, data) values (
  '00000000-0000-0000-0000-0000000d1402',
  '00000000-0000-0000-0000-00000000000a',
  '00000000-0000-0000-0000-0000000d1401',
  'basic_panel',
  '{"result":"fictional-m14"}'::jsonb
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000d1401');
select ok(
  not public.current_patient_linked(),
  'M14 setup: legacy clinic patient has no active link before backfill'
);
select is(
  (select count(*)::int from public.lab_reports),
  0,
  'M14 setup: legacy clinic patient cannot read lab_reports before backfill'
);

reset role;
select set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
set local role service_role;
select lives_ok(
  $$select public._backfill_clinic_provisioned_links()$$,
  'M14: backfill function runs'
);
reset role;

select tests.authenticate_as('00000000-0000-0000-0000-0000000d1401');
select ok(
  public.current_patient_linked(),
  'M14: legacy clinic patient is linked after backfill'
);
select is(
  (select count(*)::int from public.lab_reports),
  1,
  'M14: legacy clinic patient reads lab_reports after backfill'
);

reset role;
select set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
set local role service_role;
select is(
  (
    select count(*)::int from public.patient_record_links
    where app_user_id = '00000000-0000-0000-0000-0000000d1401'
      and status = 'active'
      and proof_method = 'clinic_provisioned'
      and telehealth_patient_id = 'clinic:00000000-0000-0000-0000-0000000d1401'
  ),
  1,
  'M14: backfilled link has clinic_provisioned proof + expected telehealth id'
);
reset role;

-- Self-signup accounts must never be backfilled, even if an org_id-bearing
-- patients row exists for them (should not happen via normal flow, but the
-- backfill predicate itself must exclude self-signup markers).
reset role;
select set_config('request.jwt.claims', '', true);
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000d1403',
  'authenticated', 'authenticated', 'm14.selfsignup@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{"role":"patient"}'::jsonb, now(), now()
);
insert into public.patient_self_signups (user_id)
values ('00000000-0000-0000-0000-0000000d1403')
on conflict do nothing;
insert into public.patients (id, org_id, display_name, mrn) values (
  '00000000-0000-0000-0000-0000000d1403',
  '00000000-0000-0000-0000-00000000000a',
  'M14 Self-signup Edge Case',
  null
);

reset role;
select set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
set local role service_role;
select lives_ok(
  $$select public._backfill_clinic_provisioned_links()$$,
  'M14: backfill function runs again (self-signup present)'
);
select is(
  (
    select count(*)::int from public.patient_record_links
    where app_user_id = '00000000-0000-0000-0000-0000000d1403'
  ),
  0,
  'M14: self-signup marked account is never backfilled a link'
);

-- Idempotent: re-running the backfill is a no-op for already-linked rows.
select lives_ok(
  $$select public._backfill_clinic_provisioned_links()$$,
  'M14: backfill function re-runs cleanly (idempotent)'
);
select is(
  (
    select count(*)::int from public.patient_record_links
    where app_user_id = '00000000-0000-0000-0000-0000000d1401'
      and status = 'active'
  ),
  1,
  'M14: still exactly one active link after re-running backfill'
);
reset role;

-- ---------------------------------------------------------------------------
-- L21: OTP body scrubbed on delivery and by age (<=10 min).
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', '', true);
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000d2101',
  'authenticated', 'authenticated', 'l21.otp@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{"role":"patient"}'::jsonb, now(), now()
);
insert into public.patient_self_signups (user_id)
values ('00000000-0000-0000-0000-0000000d2101')
on conflict do nothing;

reset role;
select set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
set local role service_role;

select lives_ok(
  $$select public.issue_telehealth_link_otp(
      '00000000-0000-0000-0000-0000000d2101',
      'th_test_l21_deliver',
      '00000000-0000-0000-0000-00000000000a',
      '482917',
      10
    )$$,
  'L21 setup: issue OTP with known plain code'
);

select ok(
  exists (
    select 1 from public.telehealth_message_outbox
    where telehealth_patient_id = 'th_test_l21_deliver' and body like '%482917%'
  ),
  'L21 setup: outbox body carries plaintext code before delivery'
);

select lives_ok(
  $$select public.mark_telehealth_outbox_delivered(
      (select id from public.telehealth_message_outbox
       where telehealth_patient_id = 'th_test_l21_deliver')
    )$$,
  'L21: mark_telehealth_outbox_delivered runs'
);

select ok(
  not exists (
    select 1 from public.telehealth_message_outbox
    where telehealth_patient_id = 'th_test_l21_deliver' and body ~ '\d{6}'
  ),
  'L21: outbox body has no 6-digit code after delivery'
);
select ok(
  (
    select scrubbed_at is not null and delivered_at is not null
    from public.telehealth_message_outbox
    where telehealth_patient_id = 'th_test_l21_deliver'
  ),
  'L21: delivered_at and scrubbed_at are set after delivery'
);

-- Age-based scrub: backdate created_at past the 10-minute TTL.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000d2102',
  'authenticated', 'authenticated', 'l21.stale@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{"role":"patient"}'::jsonb, now(), now()
);
insert into public.patient_self_signups (user_id)
values ('00000000-0000-0000-0000-0000000d2102')
on conflict do nothing;

select lives_ok(
  $$select public.issue_telehealth_link_otp(
      '00000000-0000-0000-0000-0000000d2102',
      'th_test_l21_stale',
      '00000000-0000-0000-0000-00000000000a',
      '301847',
      10
    )$$,
  'L21 setup: issue second OTP (never delivered, to be aged out)'
);

update public.telehealth_message_outbox
  set created_at = now() - interval '11 minutes'
  where telehealth_patient_id = 'th_test_l21_stale';

select ok(
  exists (
    select 1 from public.telehealth_message_outbox
    where telehealth_patient_id = 'th_test_l21_stale' and body like '%301847%'
  ),
  'L21 setup: stale outbox row still plaintext before stale scrub runs'
);

select lives_ok(
  $$select public.scrub_stale_telehealth_outbox()$$,
  'L21: scrub_stale_telehealth_outbox runs'
);

select ok(
  not exists (
    select 1 from public.telehealth_message_outbox
    where telehealth_patient_id = 'th_test_l21_stale' and body ~ '\d{6}'
  ),
  'L21: stale (>10m) outbox body scrubbed of 6-digit code'
);
select ok(
  (
    select scrubbed_at is not null
    from public.telehealth_message_outbox
    where telehealth_patient_id = 'th_test_l21_stale'
  ),
  'L21: scrubbed_at set for stale row'
);

-- Audit stays free of plaintext OTP (existing M13 behaviour, re-asserted).
select ok(
  not exists (
    select 1 from public.audit_log
    where event_type = 'patient_link_otp_issued'
      and (metadata::text like '%482917%' or metadata::text like '%301847%')
  ),
  'L21: audit_log metadata never contains a plain OTP'
);
reset role;

-- ---------------------------------------------------------------------------
-- L22: cross-clinic re-bind refused when patients.org_id differs from the
-- redeem target org; same-org re-bind after unlink still succeeds.
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', '', true);
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000d2201',
  'authenticated', 'authenticated', 'l22.patient@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{"role":"patient"}'::jsonb, now(), now()
);
insert into public.patient_self_signups (user_id)
values ('00000000-0000-0000-0000-0000000d2201')
on conflict do nothing;

select tests.authenticate_as('00000000-0000-0000-0000-0000000d2201');

-- First bind: org A, via clinic code.
reset role;
select set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
set local role service_role;
select lives_ok(
  $$select public.issue_clinic_link_code(
      'th_test_l22_orga',
      '00000000-0000-0000-0000-00000000000a',
      'L22ORGA1',
      'clinic_staff',
      72
    )$$,
  'L22 setup: issue clinic code for org A'
);
reset role;

select tests.authenticate_as('00000000-0000-0000-0000-0000000d2201');
select is(
  (public.redeem_clinic_link_code('L22ORGA1')->>'ok')::boolean,
  true,
  'L22 setup: first bind to org A succeeds'
);

-- Unlink (patients.org_id stays A; link revoked).
select is(
  (public.unlink_patient_record()->>'ok')::boolean,
  true,
  'L22 setup: unlink succeeds'
);

-- Attempt redeem into org B (distinct org_id on existing patients row) -> refused.
reset role;
select set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
set local role service_role;
select lives_ok(
  $$select public.issue_clinic_link_code(
      'th_test_l22_orgb',
      '00000000-0000-0000-0000-00000000000b',
      'L22ORGB1',
      'clinic_staff',
      72
    )$$,
  'L22 setup: issue clinic code for org B'
);
reset role;

select tests.authenticate_as('00000000-0000-0000-0000-0000000d2201');
select throws_ok(
  $$select public._bind_patient_record(
      '00000000-0000-0000-0000-0000000d2201',
      '00000000-0000-0000-0000-00000000000b',
      'th_test_l22_orgb_direct',
      'clinic_code'
    )$$,
  '42501',
  'patient record belongs to another clinic',
  'L22: direct _bind_patient_record refuses cross-clinic org_id mismatch'
);

select is(
  (public.redeem_clinic_link_code('L22ORGB1')->>'error'),
  'invalid_code',
  'L22: redeem path does not expose the refusal reason (enumeration-safe shape preserved)'
);

reset role;
select set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
set local role service_role;
select is(
  (
    select org_id from public.patients
    where id = '00000000-0000-0000-0000-0000000d2201'
  ),
  '00000000-0000-0000-0000-00000000000a'::uuid,
  'L22: patients.org_id unchanged after refused cross-clinic bind attempt'
);
reset role;

-- Same-org re-bind after unlink still succeeds.
reset role;
select set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
set local role service_role;
select lives_ok(
  $$select public.issue_clinic_link_code(
      'th_test_l22_orga2',
      '00000000-0000-0000-0000-00000000000a',
      'L22ORGA2',
      'clinic_staff',
      72
    )$$,
  'L22 setup: issue second clinic code for org A (same-org re-link)'
);
reset role;

select tests.authenticate_as('00000000-0000-0000-0000-0000000d2201');
select is(
  (public.redeem_clinic_link_code('L22ORGA2')->>'ok')::boolean,
  true,
  'L22: same-org re-bind after unlink succeeds'
);

select finish();
rollback;
