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
-- L23: backfill must not re-link a patient who has any existing link row,
-- even a revoked one (i.e. someone who unlinked but still has org_id set).
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', '', true);
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000d2301',
  'authenticated', 'authenticated', 'l23.unlinked@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb, now(), now()
);

-- Clinic-provisioned patient (org_id set, no self-signup marker) who
-- previously unlinked: org_id stays put, link row remains but revoked.
insert into public.patients (id, org_id, display_name, mrn) values (
  '00000000-0000-0000-0000-0000000d2301',
  '00000000-0000-0000-0000-00000000000a',
  'L23 Previously Unlinked Patient',
  'MRN-L23'
);
insert into public.patient_record_links (
  app_user_id, org_id, telehealth_patient_id, status, linked_at, revoked_at, proof_method
) values (
  '00000000-0000-0000-0000-0000000d2301',
  '00000000-0000-0000-0000-00000000000a',
  'clinic:00000000-0000-0000-0000-0000000d2301',
  'revoked', now() - interval '1 day', now(),
  'clinic_provisioned'
);

reset role;
select set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
set local role service_role;
select lives_ok(
  $$select public._backfill_clinic_provisioned_links()$$,
  'L23: backfill function runs with a previously-unlinked patient present'
);
reset role;

select is(
  (
    select count(*)::int from public.patient_record_links
    where app_user_id = '00000000-0000-0000-0000-0000000d2301'
      and status = 'active'
  ),
  0,
  'L23: backfill does not create a new active link for a previously-unlinked patient'
);
select is(
  (
    select status from public.patient_record_links
    where app_user_id = '00000000-0000-0000-0000-0000000d2301'
  ),
  'revoked',
  'L23: previously-unlinked patient''s link row stays revoked after backfill re-runs'
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

select is(
  (
    select body from public.telehealth_message_outbox
    where telehealth_patient_id = 'th_test_l21_deliver'
  ),
  'code removed',
  'L21: outbox body is the fixed scrub text after delivery'
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
reset role;
select set_config('request.jwt.claims', '', true);
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

reset role;
select set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
set local role service_role;

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

select is(
  (
    select body from public.telehealth_message_outbox
    where telehealth_patient_id = 'th_test_l21_stale'
  ),
  'code removed',
  'L21: stale (>10m) outbox body is the fixed scrub text'
);
select ok(
  (
    select scrubbed_at is not null
    from public.telehealth_message_outbox
    where telehealth_patient_id = 'th_test_l21_stale'
  ),
  'L21: scrubbed_at set for stale row'
);

-- L24: whole body replaced with fixed text, even for a non-6-digit code
-- (alphanumeric clinic-style code here) -- not just the digit run.
reset role;
select set_config('request.jwt.claims', '', true);
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000d2401',
  'authenticated', 'authenticated', 'l24.altcode@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{"role":"patient"}'::jsonb, now(), now()
);
insert into public.patient_self_signups (user_id)
values ('00000000-0000-0000-0000-0000000d2401')
on conflict do nothing;

reset role;
select set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
set local role service_role;

select lives_ok(
  $$select public.issue_telehealth_link_otp(
      '00000000-0000-0000-0000-0000000d2401',
      'th_test_l24_altcode',
      '00000000-0000-0000-0000-00000000000a',
      'LNK4582Z',
      10
    )$$,
  'L24 setup: issue OTP with a non-6-digit alphanumeric code'
);

select ok(
  exists (
    select 1 from public.telehealth_message_outbox
    where telehealth_patient_id = 'th_test_l24_altcode' and body like '%LNK4582Z%'
  ),
  'L24 setup: outbox body carries the plaintext alphanumeric code before delivery'
);

select lives_ok(
  $$select public.mark_telehealth_outbox_delivered(
      (select id from public.telehealth_message_outbox
       where telehealth_patient_id = 'th_test_l24_altcode')
    )$$,
  'L24: mark_telehealth_outbox_delivered runs for alphanumeric-code message'
);

select is(
  (
    select body from public.telehealth_message_outbox
    where telehealth_patient_id = 'th_test_l24_altcode'
  ),
  'code removed',
  'L24: non-6-digit code message body is fully replaced with fixed scrub text, not partially left intact'
);
reset role;

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

-- TC-040: _bind_patient_record is internal (EXECUTE revoked from anon /
-- authenticated; only definer RPCs and service_role call it). The signed-in
-- patient can't call it at all now; the org-mismatch guard inside it is
-- still checked directly, as service_role.
select tests.authenticate_as('00000000-0000-0000-0000-0000000d2201');
select throws_ok(
  $$select public._bind_patient_record(
      '00000000-0000-0000-0000-0000000d2201',
      '00000000-0000-0000-0000-00000000000b',
      'th_test_l22_orgb_direct',
      'clinic_code'
    )$$,
  '42501',
  null,
  'TC-040: a signed-in user cannot call _bind_patient_record directly'
);
reset role;
select set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
set local role service_role;
select throws_ok(
  $$select public._bind_patient_record(
      '00000000-0000-0000-0000-0000000d2201',
      '00000000-0000-0000-0000-00000000000b',
      'th_test_l22_orgb_direct',
      'clinic_code'
    )$$,
  'P0003',
  'patient record belongs to another clinic',
  'L22: direct _bind_patient_record refuses cross-clinic org_id mismatch'
);
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000d2201');

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
