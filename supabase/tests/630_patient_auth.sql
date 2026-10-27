-- TC-012 slice 1: rate limiter, email-verification/password-reset token
-- redemption, the email_confirmed_at RLS gate (PSU-EV-01), and
-- delete_patient_app_data(). No record-matching tables here (design-only
-- until Clara checks docs/RECORD_MATCHING.md).
begin;
select no_plan();

-- ---------------------------------------------------------------------------
-- check_and_consume_rate_limit(): service_role only, fixed window.
-- ---------------------------------------------------------------------------

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select throws_ok(
  $$ select public.check_and_consume_rate_limit('t', 'k', 5, 900) $$,
  '42501', null,
  'an authenticated caller cannot execute check_and_consume_rate_limit directly - service_role only'
);

select tests.authenticate_as_anon();
select throws_ok(
  $$ select public.check_and_consume_rate_limit('t', 'k', 5, 900) $$,
  '42501', null,
  'anon cannot execute check_and_consume_rate_limit'
);

reset role;
set role service_role;
select ok(public.check_and_consume_rate_limit('rl_test', 'key-a', 3, 900), 'attempt 1 of 3 allowed');
select ok(public.check_and_consume_rate_limit('rl_test', 'key-a', 3, 900), 'attempt 2 of 3 allowed');
select ok(public.check_and_consume_rate_limit('rl_test', 'key-a', 3, 900), 'attempt 3 of 3 allowed');
select ok(not public.check_and_consume_rate_limit('rl_test', 'key-a', 3, 900), 'attempt 4 of 3 rejected (PSU-RL)');
select ok(
  public.check_and_consume_rate_limit('rl_test', 'key-b', 3, 900),
  'a different key is its own independent bucket'
);
reset role;

-- window expiry: backdate the window_start past the limit, then confirm a
-- fresh window resets the count (PSU-RL-07).
set role service_role;
update public.rate_limit_counters
  set window_start = now() - interval '20 minutes'
  where bucket = 'rl_test' and key_hash = 'key-a';
select ok(
  public.check_and_consume_rate_limit('rl_test', 'key-a', 3, 900),
  'an expired window resets the count - a locked-out key is allowed again after the window (PSU-RL-07)'
);
reset role;

-- ---------------------------------------------------------------------------
-- email verification: issue (plain insert, service_role only table) + redeem.
-- ---------------------------------------------------------------------------

set role service_role;
insert into public.patient_email_verifications (user_id, token_hash)
values ('00000000-0000-0000-0000-0000000a1001', 'ev-hash-happy');
reset role;

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
select throws_ok(
  $$ select public.redeem_patient_email_verification('ev-hash-happy') $$,
  '42501', null,
  'an authenticated caller cannot execute redeem_patient_email_verification - service_role only'
);
reset role;

set role service_role;
select is(
  public.redeem_patient_email_verification('ev-hash-happy'),
  '00000000-0000-0000-0000-0000000a1001'::uuid,
  'a valid, unused, unexpired token redeems to its owning user id'
);
select is(
  public.redeem_patient_email_verification('ev-hash-happy'),
  null,
  'replaying the same token a second time fails (PSU-EV-03)'
);
reset role;

set role service_role;
insert into public.patient_email_verifications (user_id, token_hash, expires_at)
values ('00000000-0000-0000-0000-0000000a1001', 'ev-hash-expired', now() - interval '1 minute');
select is(
  public.redeem_patient_email_verification('ev-hash-expired'),
  null,
  'an expired token is rejected (PSU-EV-02)'
);
select is(
  public.redeem_patient_email_verification('ev-hash-does-not-exist'),
  null,
  'an unknown/forged token is rejected the same way as expired/used (PSU-EV-04)'
);
reset role;

-- ---------------------------------------------------------------------------
-- password reset: same redeem semantics, separate table/TTL.
-- ---------------------------------------------------------------------------

set role service_role;
insert into public.patient_password_resets (user_id, token_hash)
values ('00000000-0000-0000-0000-0000000a1001', 'pr-hash-happy');
select is(
  public.redeem_patient_password_reset('pr-hash-happy'),
  '00000000-0000-0000-0000-0000000a1001'::uuid,
  'a valid password-reset token redeems to its owning user id'
);
select is(
  public.redeem_patient_password_reset('pr-hash-happy'),
  null,
  'replaying a used password-reset token fails'
);

insert into public.patient_password_resets (user_id, token_hash, expires_at)
values ('00000000-0000-0000-0000-0000000a1001', 'pr-hash-expired', now() - interval '1 minute');
select is(
  public.redeem_patient_password_reset('pr-hash-expired'),
  null,
  'an expired password-reset token is rejected'
);
reset role;

-- a verification token can never be redeemed as a reset token or vice versa
-- (separate tables, not just separate "kind" column an attacker could flip).
set role service_role;
insert into public.patient_email_verifications (user_id, token_hash)
values ('00000000-0000-0000-0000-0000000a1001', 'cross-kind-hash');
select is(
  public.redeem_patient_password_reset('cross-kind-hash'),
  null,
  'a verification token hash is not accepted by redeem_patient_password_reset'
);
reset role;

-- ---------------------------------------------------------------------------
-- PSU-EV-01: no patient PHI before email_confirmed_at, even with an
-- otherwise-matching patients/patient_profiles/lab_reports/consents row.
-- ---------------------------------------------------------------------------

-- Plain inserts (no role switch): auth.users is only writable by the
-- superuser-ish role pg_prove connects as, same as 000_fixtures.sql -
-- service_role itself has no direct INSERT grant on auth.users (it goes
-- through GoTrue's admin API in real Edge Functions, never raw SQL).
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000a1099',
  'authenticated', 'authenticated', 'unverified-patient@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  null, '{"provider":"email","providers":["email"]}'::jsonb, '{"role":"patient"}'::jsonb, now(), now()
);
insert into public.patients (id, org_id, display_name, mrn) values
  ('00000000-0000-0000-0000-0000000a1099', '00000000-0000-0000-0000-00000000000a', 'Fictional Unverified Patient', 'MRN-UNV');
insert into public.patient_profiles (id, org_id, patient_id, data) values
  ('00000000-0000-0000-0000-0000000a2099', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1099', '{"note":"fictional"}');
insert into public.lab_reports (id, org_id, patient_id, report_type, data) values
  ('00000000-0000-0000-0000-0000000a3099', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1099', 'basic_panel', '{"result":"fictional"}');
insert into public.consents (id, org_id, patient_id, consent_type, granted) values
  ('00000000-0000-0000-0000-0000000a4099', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1099', 'data_sharing', true);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a1099', 'aal1');
select is(
  (select count(*)::int from public.patients where id = '00000000-0000-0000-0000-0000000a1099'),
  0,
  'an unverified patient cannot select their own patients row (PSU-EV-01)'
);
select is(
  (select count(*)::int from public.patient_profiles where patient_id = '00000000-0000-0000-0000-0000000a1099'),
  0,
  'an unverified patient cannot select their own patient_profiles row'
);
select is(
  (select count(*)::int from public.lab_reports where patient_id = '00000000-0000-0000-0000-0000000a1099'),
  0,
  'an unverified patient cannot select their own lab_reports row'
);
select is(
  (select count(*)::int from public.consents where patient_id = '00000000-0000-0000-0000-0000000a1099'),
  0,
  'an unverified patient cannot select their own consents row'
);
reset role;

-- confirm, then the same rows become visible - proves the gate is on
-- email_confirmed_at specifically, not some other accidental denial.
update auth.users set email_confirmed_at = now() where id = '00000000-0000-0000-0000-0000000a1099';

select tests.authenticate_as('00000000-0000-0000-0000-0000000a1099', 'aal1');
select is(
  (select count(*)::int from public.patients where id = '00000000-0000-0000-0000-0000000a1099'),
  1,
  'once confirmed, the same patient can select their own patients row'
);
select is(
  (select count(*)::int from public.patient_profiles where patient_id = '00000000-0000-0000-0000-0000000a1099'),
  1,
  'once confirmed, the same patient can select their own patient_profiles row'
);
reset role;

-- ---------------------------------------------------------------------------
-- delete_patient_app_data(): service_role only, clears patients row
-- (cascading to profiles/labs/consents) + outstanding tokens.
-- ---------------------------------------------------------------------------

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
select throws_ok(
  $$ select public.delete_patient_app_data('00000000-0000-0000-0000-0000000a1099'::uuid) $$,
  '42501', null,
  'an authenticated caller cannot execute delete_patient_app_data - service_role only'
);
reset role;

set role service_role;
insert into public.patient_email_verifications (user_id, token_hash) values
  ('00000000-0000-0000-0000-0000000a1099', 'leftover-ev-hash');
insert into public.patient_password_resets (user_id, token_hash) values
  ('00000000-0000-0000-0000-0000000a1099', 'leftover-pr-hash');

select lives_ok(
  $$ select public.delete_patient_app_data('00000000-0000-0000-0000-0000000a1099'::uuid) $$,
  'service_role can execute delete_patient_app_data'
);

select is(
  (select count(*)::int from public.patients where id = '00000000-0000-0000-0000-0000000a1099'),
  0,
  'delete_patient_app_data removes the patients row (PSU-DEL-02)'
);
select is(
  (select count(*)::int from public.patient_profiles where patient_id = '00000000-0000-0000-0000-0000000a1099'),
  0,
  'cascading delete removes the patient_profiles row'
);
select is(
  (select count(*)::int from public.lab_reports where patient_id = '00000000-0000-0000-0000-0000000a1099'),
  0,
  'cascading delete removes the lab_reports row'
);
select is(
  (select count(*)::int from public.consents where patient_id = '00000000-0000-0000-0000-0000000a1099'),
  0,
  'cascading delete removes the consents row'
);
select is(
  (select count(*)::int from public.patient_email_verifications where user_id = '00000000-0000-0000-0000-0000000a1099'),
  0,
  'delete_patient_app_data clears outstanding email-verification tokens (PSU-TO-08 / PSU-DEL-04 lineage: dead codes after delete)'
);
select is(
  (select count(*)::int from public.patient_password_resets where user_id = '00000000-0000-0000-0000-0000000a1099'),
  0,
  'delete_patient_app_data clears outstanding password-reset tokens'
);
reset role;

select * from finish();
rollback;
