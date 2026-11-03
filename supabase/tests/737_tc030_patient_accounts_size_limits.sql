-- TC-030 item 3 (Clara PR #25 M4): patient_accounts name and avatar_url now have
-- DB-level size/type CHECK constraints. An 81-char name and an oversized / wrong
-- type avatar are rejected (23514); an 80-char name, an exactly-at-cap avatar,
-- and a valid image data URI pass.
--
-- Also closes Clara PR #25 L1: pgTAP 734 test 9 inserted a DIFFERENT patient's
-- id, so RLS rejected it regardless of the premium column lockdown and the test
-- proved nothing about the column privilege. This file adds the missing case -
-- an INSERT of the patient's OWN new row with is_premium=true - which must be
-- denied by the column-privilege revoke (42501), not by RLS.
--
-- Fail-first: on the pre-20261102163000 schema there are no name/avatar_url
-- CHECK constraints, so the oversized/wrong-type inserts below would succeed
-- instead of raising 23514 (Clara accepted a 20,000-char name and a 4 MB avatar
-- at 204). The L1 own-row is_premium insert already fails 42501 on the current
-- schema (that is the point - it is the real test 734 test 9 should have been).
begin;
select no_plan();

select tests.authenticate_as('00000000-0000-0000-0000-0000000a6002', 'aal2'); -- patient_a2, no row yet

-- name length: 81 chars rejected, 80 accepted.
select throws_ok(
  $$ insert into public.patient_accounts (patient_id, name)
     values ('00000000-0000-0000-0000-0000000a6002', repeat('n', 81)) $$,
  '23514', null,
  'an 81-char display name is rejected by the DB CHECK constraint'
);
select is(
  (select count(*)::int from public.patient_accounts where patient_id = '00000000-0000-0000-0000-0000000a6002'),
  0,
  'the oversized-name attempt created no patient_accounts row'
);

-- avatar_url: an image data URI longer than the 3 MB cap is rejected.
select throws_ok(
  $$ insert into public.patient_accounts (patient_id, avatar_url)
     values ('00000000-0000-0000-0000-0000000a6002',
             'data:image/jpeg;base64,' || repeat('A', 3145729)) $$,
  '23514', null,
  'an oversized (> 3 MB) avatar data URI is rejected by the DB CHECK constraint'
);

-- avatar_url: a non-image data URI is rejected by the type check even when short.
select throws_ok(
  $$ insert into public.patient_accounts (patient_id, avatar_url)
     values ('00000000-0000-0000-0000-0000000a6002',
             'data:application/pdf;base64,AAAA') $$,
  '23514', null,
  'a non-image data: URI avatar is rejected by the DB CHECK constraint'
);

select is(
  (select count(*)::int from public.patient_accounts where patient_id = '00000000-0000-0000-0000-0000000a6002'),
  0,
  'no row was created by any of the rejected avatar attempts'
);

-- Valid: an 80-char name and a small image data URI are accepted together.
select lives_ok(
  $$ insert into public.patient_accounts (patient_id, name, avatar_url)
     values ('00000000-0000-0000-0000-0000000a6002', repeat('n', 80),
             'data:image/png;base64,iVBORw0KGgo=') $$,
  'an 80-char name and a valid image data URI are accepted'
);
select is(
  (select char_length(name) from public.patient_accounts where patient_id = '00000000-0000-0000-0000-0000000a6002'),
  80,
  'the exactly-at-cap (80) name was stored'
);

-- A plain https:// avatar URL (social-login sync) is not subject to the image/*
-- data-URI check and passes, as long as it is under the length cap.
select lives_ok(
  $$ update public.patient_accounts
       set avatar_url = 'https://cdn.example.test/avatars/a2.jpg'
     where patient_id = '00000000-0000-0000-0000-0000000a6002' $$,
  'a plain https:// avatar URL is accepted (type check only applies to data: URIs)'
);

-- Clara PR #25 L1: the patient's OWN new row with is_premium=true is denied by
-- the premium column-privilege revoke (42501), not by RLS. patient_a1 has no
-- row yet in this transaction.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2'); -- patient_a1
select throws_ok(
  $$ insert into public.patient_accounts (patient_id, is_premium)
     values ('00000000-0000-0000-0000-0000000a1001', true) $$,
  '42501', null,
  'L1: patient_a1 cannot INSERT their OWN new row with is_premium=true (column privilege, not RLS)'
);
select is(
  (select count(*)::int from public.patient_accounts where patient_id = '00000000-0000-0000-0000-0000000a1001'),
  0,
  'L1: the blocked own-row is_premium insert created no row'
);

select * from finish();
rollback;
