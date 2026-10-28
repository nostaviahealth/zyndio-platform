-- TC-012 slice 1: rate limiter, email-verification/password-reset token
-- redemption, the email_confirmed_at RLS gate (PSU-EV-01), and
-- delete_patient_app_data(), and PSU-TO-15 (verified unlinked self-signup
-- reads nothing). No matching redeem/bind RPCs (design-only until Clara
-- Approves the revised docs/RECORD_MATCHING.md).
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
  null, '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now()
);
insert into public.patients (id, org_id, display_name, mrn) values
  ('00000000-0000-0000-0000-0000000a1099', '00000000-0000-0000-0000-00000000000a', 'Fictional Unverified Patient', 'MRN-UNV');
insert into public.patient_profiles (id, org_id, patient_id, data) values
  ('00000000-0000-0000-0000-0000000a2099', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1099', '{"note":"fictional"}');
insert into public.lab_reports (id, org_id, patient_id, report_type, data) values
  ('00000000-0000-0000-0000-0000000a3099', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1099', 'basic_panel', '{"result":"fictional"}');
insert into public.consents (id, org_id, patient_id, consent_type, granted) values
  ('00000000-0000-0000-0000-0000000a4099', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1099', 'data_sharing', true);
-- M12: clinical reads require an active link (org_id alone is not enough).
insert into public.patient_record_links (
  app_user_id, org_id, telehealth_patient_id, status, linked_at, proof_method
) values (
  '00000000-0000-0000-0000-0000000a1099',
  '00000000-0000-0000-0000-00000000000a',
  'clinic:00000000-0000-0000-0000-0000000a1099',
  'active', now(), 'clinic_provisioned'
);

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


-- ---------------------------------------------------------------------------
-- PSU-TO-15 (Clara RECORD_MATCHING #5): verified self-signup with NO
-- public.patients row (and therefore no org_id / no active link) reads
-- zero rows from every clinical table. patient-signup never inserts
-- patients; this fixture mirrors that shape.
-- ---------------------------------------------------------------------------

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000a10aa',
  'authenticated', 'authenticated', 'verified-unlinked@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"role":"patient"}'::jsonb, now(), now()
);
-- Intentionally NO insert into public.patients / profiles / labs / consents.

select tests.authenticate_as('00000000-0000-0000-0000-0000000a10aa', 'aal1');
select is(
  (select count(*)::int from public.patients),
  0,
  'PSU-TO-15: verified unlinked self-signup selects 0 patients rows'
);
select is(
  (select count(*)::int from public.patient_profiles),
  0,
  'PSU-TO-15: verified unlinked self-signup selects 0 patient_profiles rows'
);
select is(
  (select count(*)::int from public.lab_reports),
  0,
  'PSU-TO-15: verified unlinked self-signup selects 0 lab_reports rows'
);
select is(
  (select count(*)::int from public.consents),
  0,
  'PSU-TO-15: verified unlinked self-signup selects 0 consents rows'
);
select ok(
  not public.current_patient_linked(),
  'PSU-TO-15: current_patient_linked() is false for verified unlinked self-signup'
);
reset role;


-- ---------------------------------------------------------------------------
-- PSU-RL-03 helpers: peek_rate_limit does not consume; consume only on fail.
-- ---------------------------------------------------------------------------
select ok(
  public.peek_rate_limit('patient_login_ip', 'ip-peek-a', 3, 900),
  'PSU-RL-03: peek allows when no counter row exists'
);
select ok(public.check_and_consume_rate_limit('patient_login_ip', 'ip-peek-a', 3, 900), 'consume 1');
select ok(public.check_and_consume_rate_limit('patient_login_ip', 'ip-peek-a', 3, 900), 'consume 2');
select ok(public.check_and_consume_rate_limit('patient_login_ip', 'ip-peek-a', 3, 900), 'consume 3');
select ok(
  not public.peek_rate_limit('patient_login_ip', 'ip-peek-a', 3, 900),
  'PSU-RL-03: peek denies after failure budget exhausted'
);
select ok(
  not public.check_and_consume_rate_limit('patient_login_ip', 'ip-peek-a', 3, 900),
  'PSU-RL-03: further consume rejects'
);
-- expired window restores peek
update public.rate_limit_counters
set window_start = now() - interval '16 minutes'
where bucket = 'patient_login_ip' and key_hash = 'ip-peek-a';
select ok(
  public.peek_rate_limit('patient_login_ip', 'ip-peek-a', 3, 900),
  'PSU-RL-03: peek allows again after window expiry'
);

-- ---------------------------------------------------------------------------
-- PSU-EV-05: redeem_patient_email_change; old email authoritative until redeem.
-- ---------------------------------------------------------------------------
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000a20bb',
  'authenticated', 'authenticated', 'jordan.old@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"role":"patient"}'::jsonb, now(), now()
);

insert into public.patient_email_change_requests (
  user_id, new_email, token_hash, expires_at
) values (
  '00000000-0000-0000-0000-0000000a20bb',
  'jordan.new@example.test',
  'ev05-token-hash-aaa',
  now() + interval '24 hours'
);

-- Before redeem, auth email is still the old one.
select is(
  (select email from auth.users where id = '00000000-0000-0000-0000-0000000a20bb'),
  'jordan.old@example.test',
  'PSU-EV-05: old email remains authoritative before confirm'
);

select is(
  (public.redeem_patient_email_change('ev05-token-hash-aaa')->>'ok')::boolean,
  true,
  'PSU-EV-05: redeem succeeds with valid token'
);

select is(
  (select email from auth.users where id = '00000000-0000-0000-0000-0000000a20bb'),
  'jordan.new@example.test',
  'PSU-EV-05: email updated only after confirm'
);

select is(
  (public.redeem_patient_email_change('ev05-token-hash-aaa')->>'ok')::boolean,
  false,
  'PSU-EV-05: token reuse fails'
);

select is(
  (public.redeem_patient_email_change('forged-token')->>'error'),
  'invalid_or_expired_link',
  'PSU-EV-05: forged token rejected'
);

select * from finish();
rollback;
