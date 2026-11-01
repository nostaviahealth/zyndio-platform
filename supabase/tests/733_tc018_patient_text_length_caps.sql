-- TC-018 (Henry's calls, 1 Nov 2026; Clara PR #23 review finding #2): DB-level
-- backstop for patients.display_name/mrn length caps, independent of the
-- create-patient Edge Function's own validation. Fails now: no such
-- constraint exists, so these overlong inserts succeed.
begin;
select no_plan();

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a

-- a9001 ("spare-xorg@example.test", 000_fixtures.sql): never given an
-- org_members/patients row in global fixtures, and the only other reuse
-- (200_cross_org_matrix.sql) always ends in a denied cross-org insert, so it
-- is still patient-less at the start of this file's own transaction.
select throws_ok(
  $$ select public.create_patient_record(
       '00000000-0000-0000-0000-0000000a9001',
       repeat('x', 201),
       null
     ) $$,
  '23514', null,
  'create_patient_record: a display_name over 200 chars is rejected by the DB CHECK constraint'
);
select is(
  (select count(*)::int from public.patients where id = '00000000-0000-0000-0000-0000000a9001'),
  0,
  'the oversized display_name attempt created no patient row'
);

select throws_ok(
  $$ select public.create_patient_record(
       '00000000-0000-0000-0000-0000000a9001',
       'Fictional Spare Patient',
       repeat('9', 65)
     ) $$,
  '23514', null,
  'create_patient_record: an mrn over 64 chars is rejected by the DB CHECK constraint'
);
select is(
  (select count(*)::int from public.patients where id = '00000000-0000-0000-0000-0000000a9001'),
  0,
  'the oversized mrn attempt created no patient row either'
);

select public.create_patient_record(
  '00000000-0000-0000-0000-0000000a9001',
  repeat('x', 200),
  repeat('9', 64)
);
select is(
  (select display_name from public.patients where id = '00000000-0000-0000-0000-0000000a9001'),
  repeat('x', 200),
  'exactly-at-the-cap display_name (200) and mrn (64) are accepted'
);

select * from finish();
rollback;
