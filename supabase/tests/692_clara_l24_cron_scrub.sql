-- Clara L24: behavioral check that the pg_cron wrapper
-- (_cron_scrub_stale_telehealth_outbox) actually clears stale plaintext
-- bodies to the fixed 'code removed' text and leaves fresh rows alone.
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
  '00000000-0000-0000-0000-0000000d2402',
  'authenticated', 'authenticated', 'l24.cron.stale@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{"role":"patient"}'::jsonb, now(), now()
),
(
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000d2403',
  'authenticated', 'authenticated', 'l24.cron.fresh@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{"role":"patient"}'::jsonb, now(), now()
);
insert into public.patient_self_signups (user_id) values
  ('00000000-0000-0000-0000-0000000d2402'),
  ('00000000-0000-0000-0000-0000000d2403')
on conflict do nothing;

reset role;
select set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
set local role service_role;

-- Stale row: issued, never delivered, aged past the 10-minute TTL.
select lives_ok(
  $$select public.issue_telehealth_link_otp(
      '00000000-0000-0000-0000-0000000d2402',
      'th_test_l24_cron_stale',
      '00000000-0000-0000-0000-00000000000a',
      '914205',
      10
    )$$,
  'L24 cron setup: issue OTP for the stale row'
);
update public.telehealth_message_outbox
  set created_at = now() - interval '11 minutes'
  where telehealth_patient_id = 'th_test_l24_cron_stale';

-- Fresh row: issued moments ago, well inside the 10-minute TTL.
select lives_ok(
  $$select public.issue_telehealth_link_otp(
      '00000000-0000-0000-0000-0000000d2403',
      'th_test_l24_cron_fresh',
      '00000000-0000-0000-0000-00000000000a',
      '377610',
      10
    )$$,
  'L24 cron setup: issue OTP for the fresh row'
);

reset role;

-- pg_cron runs scheduled jobs as the bootstrap/postgres role; the pgTAP
-- test runner role stands in for that here (execute is revoked from
-- anon/authenticated, see 20261027191300_tc012_clara_l21_pg_cron.sql).
select lives_ok(
  $$select public._cron_scrub_stale_telehealth_outbox()$$,
  'L24 cron: _cron_scrub_stale_telehealth_outbox runs'
);

select is(
  (
    select body from public.telehealth_message_outbox
    where telehealth_patient_id = 'th_test_l24_cron_stale'
  ),
  'code removed',
  'L24 cron: stale row body is replaced with the fixed scrub text'
);
select ok(
  (
    select scrubbed_at is not null
    from public.telehealth_message_outbox
    where telehealth_patient_id = 'th_test_l24_cron_stale'
  ),
  'L24 cron: stale row scrubbed_at is set'
);

select ok(
  (
    select body like '%377610%' and scrubbed_at is null
    from public.telehealth_message_outbox
    where telehealth_patient_id = 'th_test_l24_cron_fresh'
  ),
  'L24 cron: fresh (<10m) row is left untouched by the cron wrapper'
);

select finish();
rollback;
