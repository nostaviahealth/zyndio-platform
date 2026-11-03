-- Clara REVIEW_TC-012_MATCHING: H-M2, H-M3, M12, M13, L20.
-- Fictional pepper only — never a real production value.
begin;
select no_plan();

-- ---------------------------------------------------------------------------
-- H-M2: missing Vault pepper must refuse issue + redeem (fail closed).
-- ---------------------------------------------------------------------------
delete from vault.secrets where name = 'link_code_pepper';

select throws_ok(
  $$select public._link_code_pepper()$$,
  'P0001',
  'link_code_pepper secret is not configured in Vault',
  'H-M2: _link_code_pepper refuses when Vault secret missing'
);

select throws_ok(
  $$select public.link_code_mac('123456')$$,
  'P0001',
  'link_code_pepper secret is not configured in Vault',
  'H-M2: redeem/HMAC refuses when Vault pepper missing'
);

reset role;
select set_config('request.jwt.claims', json_build_object('role','service_role')::text, true);
set local role service_role;

select throws_ok(
  $$select public.issue_telehealth_link_otp(
      '00000000-0000-0000-0000-0000000a1001',
      'th_test_hm2_missing',
      '00000000-0000-0000-0000-00000000000a',
      '123456',
      10
    )$$,
  'P0001',
  'link_code_pepper secret is not configured in Vault',
  'H-M2: issue_telehealth_link_otp refuses when Vault pepper missing'
);

select throws_ok(
  $$select public.issue_clinic_link_code(
      'th_test_hm2_clinic',
      '00000000-0000-0000-0000-00000000000a',
      'ABCD2345',
      'clinic_staff',
      72
    )$$,
  'P0001',
  'link_code_pepper secret is not configured in Vault',
  'H-M2: issue_clinic_link_code refuses when Vault pepper missing'
);

reset role;
select set_config('request.jwt.claims', '', true);

select vault.create_secret(
  'tc012-pgtap-fictional-pepper-not-for-prod',
  'link_code_pepper',
  'pgTAP fictional pepper — never a real value'
);

select isnt(
  public._link_code_pepper(),
  'tc012-dev-link-code-pepper-not-for-prod',
  'H-M2: hard-coded dev fallback string is gone from _link_code_pepper'
);

select ok(
  length(public.link_code_mac('ABCD2345')) = 64,
  'H-M2 setup: fictional Vault pepper enables link_code_mac'
);

-- ---------------------------------------------------------------------------
-- H-M3: coordinator / platform admin cannot redeem onto their own account.
-- ---------------------------------------------------------------------------
-- Self-signup markers so staff are not blocked for other reasons first.
insert into public.patient_self_signups (user_id) values
  ('00000000-0000-0000-0000-0000000a0003'),
  ('00000000-0000-0000-0000-0000000af001')
on conflict (user_id) do nothing;

reset role;
select set_config('request.jwt.claims', json_build_object('role','service_role')::text, true);
set local role service_role;

select lives_ok(
  $$select public.issue_clinic_link_code(
      'th_test_hm3_staff',
      '00000000-0000-0000-0000-00000000000a',
      'K7Q42MRX',
      'clinic_staff',
      72
    )$$,
  'H-M3 setup: issue clinic code for staff-redeem probe'
);

select lives_ok(
  $$select public.issue_telehealth_link_otp(
      '00000000-0000-0000-0000-0000000a0003',
      'th_test_hm3_otp_staff',
      '00000000-0000-0000-0000-00000000000a',
      '654321',
      10
    )$$,
  'H-M3 setup: issue OTP targeted at coordinator'
);

select lives_ok(
  $$select public.issue_telehealth_link_otp(
      '00000000-0000-0000-0000-0000000af001',
      'th_test_hm3_otp_admin',
      '00000000-0000-0000-0000-00000000000a',
      '112233',
      10
    )$$,
  'H-M3 setup: issue OTP targeted at platform admin'
);

reset role;

-- Coordinator redeems clinic code on own account → refused.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003');
select throws_ok(
  $$select public.redeem_clinic_link_code('K7Q42MRX')$$,
  '42501',
  'cannot bind a patient record to a staff account',
  'H-M3: coordinator redeem clinic code on own account refused'
);

select throws_ok(
  $$select public.redeem_telehealth_link_code('654321')$$,
  '42501',
  'cannot bind a patient record to a staff account',
  'H-M3: coordinator redeem OTP on own account refused'
);

-- Platform admin OTP redeem refused.
select tests.authenticate_as('00000000-0000-0000-0000-0000000af001');
select throws_ok(
  $$select public.redeem_telehealth_link_code('112233')$$,
  '42501',
  'cannot bind a patient record to a platform admin account',
  'H-M3: platform admin redeem OTP refused'
);

-- ---------------------------------------------------------------------------
-- M12: unlink revokes clinical reads for clinic-provisioned patients.
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', '', true);
-- Fresh clinic-provisioned patient (org_id set + active link via create_patient_record).
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000c6801',
  'authenticated', 'authenticated', 'm12.clinic@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb, now(), now()
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003'); -- care_coordinator (TC-030: create is coordinator-only)
select lives_ok(
  $$select public.create_patient_record(
      '00000000-0000-0000-0000-0000000c6801',
      'M12 Clinic Patient',
      'MRN-M12'
    )$$,
  'M12 setup: a care_coordinator creates a clinic-provisioned patient (with active link)'
);

insert into public.lab_reports (id, org_id, patient_id, report_type, data)
values (
  '00000000-0000-0000-0000-0000000c6802',
  '00000000-0000-0000-0000-00000000000a',
  '00000000-0000-0000-0000-0000000c6801',
  'basic_panel',
  '{"result":"fictional-m12"}'::jsonb
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000c6801');
select ok(
  public.current_patient_linked(),
  'M12: clinic-provisioned patient is linked before unlink'
);
select is(
  (select count(*)::int from public.lab_reports),
  1,
  'M12: clinic-provisioned patient sees lab_reports while linked'
);

select is(
  (public.unlink_patient_record()->>'ok')::boolean,
  true,
  'M12: unlink succeeds for clinic-provisioned patient'
);

select ok(
  not public.current_patient_linked(),
  'M12: after unlink, current_patient_linked is false despite patients.org_id'
);
select is(
  (select count(*)::int from public.patients),
  0,
  'M12: after unlink, clinic-provisioned patient sees zero patients rows'
);
select is(
  (select count(*)::int from public.lab_reports),
  0,
  'M12: after unlink, clinic-provisioned patient sees zero lab_reports'
);

-- Org_id alone must not grant access (no active link). Check row as service_role
-- because patient RLS correctly hides it after unlink.
reset role;
select set_config('request.jwt.claims', json_build_object('role','service_role')::text, true);
set local role service_role;
select ok(
  exists (
    select 1 from public.patients
    where id = '00000000-0000-0000-0000-0000000c6801'
      and org_id is not null
  ),
  'M12 setup: patients.org_id still set after unlink (RLS must not use it)'
);
reset role;
select set_config('request.jwt.claims', '', true);

-- ---------------------------------------------------------------------------
-- M13: OTP plain code reaches telehealth outbox; never audit metadata.
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', '', true);
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000c6803',
  'authenticated', 'authenticated', 'm13.otp@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{"role":"patient"}'::jsonb, now(), now()
);
insert into public.patient_self_signups (user_id)
values ('00000000-0000-0000-0000-0000000c6803')
on conflict do nothing;

reset role;
select set_config('request.jwt.claims', json_build_object('role','service_role')::text, true);
set local role service_role;

select lives_ok(
  $$select public.issue_telehealth_link_otp(
      '00000000-0000-0000-0000-0000000c6803',
      'th_test_m13_otp',
      '00000000-0000-0000-0000-00000000000a',
      '918273',
      10
    )$$,
  'M13 setup: issue OTP with known plain code'
);

reset role;

select ok(
  exists (
    select 1 from public.telehealth_message_outbox
    where telehealth_patient_id = 'th_test_m13_otp'
      and body like '%918273%'
  ),
  'M13: telehealth outbox body carries the redeemable OTP'
);

select ok(
  not exists (
    select 1 from public.audit_log
    where event_type = 'patient_link_otp_issued'
      and metadata::text like '%918273%'
  ),
  'M13: audit_log metadata never contains the plain OTP'
);

-- Code in outbox must actually redeem.
select tests.authenticate_as('00000000-0000-0000-0000-0000000c6803');
select is(
  (public.redeem_telehealth_link_code('918273')->>'ok')::boolean,
  true,
  'M13: OTP from outbox body redeems successfully'
);

-- ---------------------------------------------------------------------------
-- L20: breaker threshold from GUC; documented default 100.
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', '', true);

select is(
  public._clinic_code_breaker_threshold(),
  100,
  'L20: default breaker threshold is 100'
);

select set_config('app.clinic_code_breaker_threshold', '3', true);
select is(
  public._clinic_code_breaker_threshold(),
  3,
  'L20: GUC app.clinic_code_breaker_threshold overrides default'
);

-- Trip with threshold 3 after 3 bumps.
select set_config('request.jwt.claims', json_build_object('role','service_role')::text, true);
-- Breaker helpers are internal; bump via failed clinic redeem path.
select tests.authenticate_as('00000000-0000-0000-0000-0000000c6803');
-- Already linked from M13 — unlink first so redeem path can run wrong tries.
select public.unlink_patient_record();

select is(
  (public.redeem_clinic_link_code('ZZZZ9999')->>'error'),
  'invalid_code',
  'L20 setup: wrong clinic code 1'
);
select is(
  (public.redeem_clinic_link_code('ZZZZ9999')->>'error'),
  'invalid_code',
  'L20 setup: wrong clinic code 2'
);
select is(
  (public.redeem_clinic_link_code('ZZZZ9999')->>'error'),
  'invalid_code',
  'L20 setup: wrong clinic code 3'
);
select is(
  (public.redeem_clinic_link_code('ZZZZ9999')->>'error'),
  'unavailable',
  'L20: breaker trips at configured threshold (3)'
);

select set_config('app.clinic_code_breaker_threshold', '', true);

select finish();
rollback;
