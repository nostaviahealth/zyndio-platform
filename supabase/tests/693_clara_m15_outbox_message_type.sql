-- Clara M15: outbox message_type code|notice; scrub only code rows;
-- sender (list_pending_telehealth_outbox) skips scrubbed rows.
-- Fictional data only.
begin;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000d1501',
  'authenticated', 'authenticated', 'm15.notice@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{"role":"patient"}'::jsonb, now(), now()
),
(
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000d1502',
  'authenticated', 'authenticated', 'm15.code@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{"role":"patient"}'::jsonb, now(), now()
);
insert into public.patient_self_signups (user_id) values
  ('00000000-0000-0000-0000-0000000d1501'),
  ('00000000-0000-0000-0000-0000000d1502')
on conflict do nothing;

-- Org A is seeded by 000_fixtures.sql; Vault pepper by seed.sql.

reset role;
select set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
set local role service_role;

-- -----------------------------------------------------------------------
-- Setup: one notice (via _enqueue_link_notices) and one code (via OTP).
-- Age both past the 10-minute scrub TTL.
-- -----------------------------------------------------------------------
select lives_ok(
  $$select public._enqueue_link_notices(
      '00000000-0000-0000-0000-0000000d1501',
      '00000000-0000-0000-0000-00000000000a',
      'th_test_m15_notice',
      'linked'
    )$$,
  'M15 setup: enqueue link notice'
);

select lives_ok(
  $$select public.issue_telehealth_link_otp(
      '00000000-0000-0000-0000-0000000d1502',
      'th_test_m15_code',
      '00000000-0000-0000-0000-00000000000a',
      '582917',
      10
    )$$,
  'M15 setup: issue OTP code row'
);

select is(
  (
    select message_type from public.telehealth_message_outbox
    where telehealth_patient_id = 'th_test_m15_notice'
  ),
  'notice',
  'M15: _enqueue_link_notices inserts message_type = notice'
);

select is(
  (
    select message_type from public.telehealth_message_outbox
    where telehealth_patient_id = 'th_test_m15_code'
  ),
  'code',
  'M15: issue_telehealth_link_otp inserts message_type = code'
);

update public.telehealth_message_outbox
  set created_at = now() - interval '11 minutes'
  where telehealth_patient_id in ('th_test_m15_notice', 'th_test_m15_code');

-- Capture the exact notice body before scrub.
create temporary table m15_notice_before as
  select body from public.telehealth_message_outbox
  where telehealth_patient_id = 'th_test_m15_notice';

-- -----------------------------------------------------------------------
-- Stale scrub (service_role): notice keeps exact text; code is cleared+marked.
-- -----------------------------------------------------------------------
select lives_ok(
  $$select public.scrub_stale_telehealth_outbox()$$,
  'M15: scrub_stale_telehealth_outbox runs'
);

select is(
  (
    select body from public.telehealth_message_outbox
    where telehealth_patient_id = 'th_test_m15_notice'
  ),
  (select body from m15_notice_before),
  'M15: notice older than 10 minutes keeps its exact text after stale scrub'
);

select ok(
  (
    select scrubbed_at is null
    from public.telehealth_message_outbox
    where telehealth_patient_id = 'th_test_m15_notice'
  ),
  'M15: notice is not marked scrubbed by stale scrub'
);

select is(
  (
    select body from public.telehealth_message_outbox
    where telehealth_patient_id = 'th_test_m15_code'
  ),
  'code removed',
  'M15: stale code row body is replaced with fixed scrub text'
);

select ok(
  (
    select scrubbed_at is not null
    from public.telehealth_message_outbox
    where telehealth_patient_id = 'th_test_m15_code'
  ),
  'M15: stale code row is marked scrubbed_at'
);

-- -----------------------------------------------------------------------
-- Cron wrapper: another notice aged past TTL still keeps exact text.
-- -----------------------------------------------------------------------
select lives_ok(
  $$select public._enqueue_link_notices(
      '00000000-0000-0000-0000-0000000d1501',
      '00000000-0000-0000-0000-00000000000a',
      'th_test_m15_notice_cron',
      'unlinked'
    )$$,
  'M15 setup: enqueue unlink notice for cron check'
);

update public.telehealth_message_outbox
  set created_at = now() - interval '12 minutes'
  where telehealth_patient_id = 'th_test_m15_notice_cron';

create temporary table m15_notice_cron_before as
  select body from public.telehealth_message_outbox
  where telehealth_patient_id = 'th_test_m15_notice_cron';

reset role;
select lives_ok(
  $$select public._cron_scrub_stale_telehealth_outbox()$$,
  'M15: _cron_scrub_stale_telehealth_outbox runs'
);

select is(
  (
    select body from public.telehealth_message_outbox
    where telehealth_patient_id = 'th_test_m15_notice_cron'
  ),
  (select body from m15_notice_cron_before),
  'M15: notice older than 10 minutes keeps its exact text after cron wrapper'
);

select ok(
  (
    select scrubbed_at is null and body = (select body from m15_notice_cron_before)
    from public.telehealth_message_outbox
    where telehealth_patient_id = 'th_test_m15_notice_cron'
  ),
  'M15: cron wrapper leaves notice unmarked and unchanged'
);

-- -----------------------------------------------------------------------
-- Sender skips scrubbed rows (list_pending_telehealth_outbox).
-- -----------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
set local role service_role;

-- Fresh (unscrubbed) notice should appear; scrubbed code must not.
select ok(
  (
    select count(*) = 0
    from public.list_pending_telehealth_outbox()
    where telehealth_patient_id = 'th_test_m15_code'
       or body = 'code removed'
  ),
  'M15: sender skips scrubbed code rows (never would send "code removed")'
);

select ok(
  (
    select count(*) >= 1
    from public.list_pending_telehealth_outbox()
    where telehealth_patient_id = 'th_test_m15_notice_cron'
      and message_type = 'notice'
  ),
  'M15: sender still returns unscrubbed notice rows'
);

-- Fresh code that is not yet scrubbed must still be pending.
select lives_ok(
  $$select public.issue_telehealth_link_otp(
      '00000000-0000-0000-0000-0000000d1502',
      'th_test_m15_code_fresh',
      '00000000-0000-0000-0000-00000000000a',
      '441029',
      10
    )$$,
  'M15 setup: issue fresh OTP for sender-pending check'
);

select ok(
  (
    select count(*) = 1
    from public.list_pending_telehealth_outbox()
    where telehealth_patient_id = 'th_test_m15_code_fresh'
      and body like '%441029%'
      and message_type = 'code'
  ),
  'M15: sender returns fresh unscrubbed code rows'
);

select * from finish();
rollback;
