-- Permanent regression for Clara's PR #4 pre-review probes
-- (work/clara-pr4-rls-probes.sql, run by hand against an isolated stack).
-- Each probe here used an ALLOWED result as its finding; this file re-runs
-- the same shapes and asserts DENIED now that review group A has landed.
-- P7/P8 are not part of group A's scope and are not included here.
begin;
select no_plan();

-- P1: org_admin_a direct REST-style UPDATE of another member's role/status
-- (bypassing change_member_role) - fixed by dropping org_members_admin_update
-- and revoking UPDATE from authenticated (H1). See 020_org_members.sql for
-- the full org_members matrix.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
select throws_ok(
  $$ update public.org_members set role = 'read_only' where user_id = '00000000-0000-0000-0000-0000000a0002' $$,
  null, null,
  'P1 denied: org_admin_a cannot set another member''s role via a direct UPDATE'
);
select throws_ok(
  $$ update public.org_members set status = 'deactivated' where user_id = '00000000-0000-0000-0000-0000000a0003' $$,
  null, null,
  'P1b denied: org_admin_a cannot set another member''s status via a direct UPDATE'
);

-- P2: org_admin_a re-points a membership row at an arbitrary auth user.
select throws_ok(
  $$ update public.org_members set user_id = '00000000-0000-0000-0000-0000000a9001' where user_id = '00000000-0000-0000-0000-0000000a0004' $$,
  null, null,
  'P2 denied: org_admin_a cannot re-point a membership row at an arbitrary auth user'
);

-- P3/P4 (finding M1): patient_a1 moves their own clinical rows to org B -
-- fixed by making patients.org_id immutable for the patient and pinning
-- org_id on the patient-owned child tables to the patient's own org.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1');
select throws_ok(
  $$ update public.patients set org_id = '00000000-0000-0000-0000-00000000000b' where id = '00000000-0000-0000-0000-0000000a1001' $$,
  null, null,
  'P3 denied: patient_a1 cannot move their own patients.org_id to org B'
);
select throws_ok(
  $$ update public.patient_profiles set org_id = '00000000-0000-0000-0000-00000000000b' where patient_id = '00000000-0000-0000-0000-0000000a1001' $$,
  null, null,
  'P3b denied: patient_a1 cannot move their own patient_profiles.org_id to org B'
);
select throws_ok(
  $$ insert into public.lab_reports (org_id, patient_id, report_type) values ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000a1001', 'x') $$,
  null, null,
  'P4 denied: patient_a1 cannot insert a lab_report into org B'
);
select throws_ok(
  $$ insert into public.consents (org_id, patient_id, consent_type, granted) values ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000a1001', 'x', true) $$,
  null, null,
  'P4b denied: patient_a1 cannot insert a consent into org B'
);

-- P5: read_only sees clinical detail - fixed by dropping read_only's SELECT
-- on patient_profiles/lab_reports/consents (H2). patients (list columns
-- only) is unaffected and still readable.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2');
select is(
  (select count(*) from public.lab_reports)::int, 0,
  'P5 denied: read_only_a sees no lab_reports rows at all'
);
select is(
  (select count(*) from public.patient_profiles)::int, 0,
  'P5b denied: read_only_a sees no patient_profiles rows at all'
);
select is(
  (select count(*) from public.consents)::int, 0,
  'P5c denied: read_only_a sees no consents rows at all'
);
select is(
  (select display_name from public.patients where id = '00000000-0000-0000-0000-0000000a1001'),
  'Fictional Patient A1',
  'P5d: read_only_a still sees the patient list (display columns only - no clinical detail there to begin with)'
);

-- P6: care coordinator updates lab report data ("Needs review" confirm) -
-- fixed by removing care_coordinator from the lab_reports UPDATE policy,
-- leaving physician as the only role that can update (Henry ruling 2 / A5).
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2'); -- care_coordinator_a
select is(
  (select data from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  '{"result":"fictional"}'::jsonb,
  'P6 denied: care_coordinator_a''s UPDATE of lab_reports.data matches 0 rows (no UPDATE policy for this role)'
);
-- physicians keep the write.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
update public.lab_reports set data = '{"confirmed":true}'::jsonb where id = '00000000-0000-0000-0000-0000000a3001';
select is(
  (select data from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  '{"confirmed":true}'::jsonb,
  'P6 control: physician_a can still update lab_reports.data'
);

-- P9: staff creating a patients row for an arbitrary existing auth user id
-- is NOT fixed in this pass (left as a documented TODO - see
-- step4f-summary.md). This assertion documents *current* behaviour (still
-- allowed) so a future fix flips it, rather than silently claiming coverage
-- that doesn't exist.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select lives_ok(
  $$ insert into public.patients (id, org_id) values ('00000000-0000-0000-0000-0000000a9001', '00000000-0000-0000-0000-00000000000a') $$,
  'P9 TODO (not fixed in review group A): a staff member can still create a patients row for an arbitrary auth user id in their org'
);

select * from finish();
rollback;
