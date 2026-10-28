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
  '42501', null,
  'P1 denied: org_admin_a cannot set another member''s role via a direct UPDATE'
);
select throws_ok(
  $$ update public.org_members set status = 'deactivated' where user_id = '00000000-0000-0000-0000-0000000a0003' $$,
  '42501', null,
  'P1b denied: org_admin_a cannot set another member''s status via a direct UPDATE'
);

-- P2: org_admin_a re-points a membership row at an arbitrary auth user.
select throws_ok(
  $$ update public.org_members set user_id = '00000000-0000-0000-0000-0000000a9001' where user_id = '00000000-0000-0000-0000-0000000a0004' $$,
  '42501', null,
  'P2 denied: org_admin_a cannot re-point a membership row at an arbitrary auth user'
);

-- P3/P4 (finding M1): patient_a1 moves their own clinical rows to org B -
-- fixed by making patients.org_id immutable for the patient and pinning
-- org_id on the patient-owned child tables to the patient's own org.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1');
select throws_ok(
  $$ update public.patients set org_id = '00000000-0000-0000-0000-00000000000b' where id = '00000000-0000-0000-0000-0000000a1001' $$,
  '42501', null,
  'P3 denied: patient_a1 cannot move their own patients.org_id to org B'
);
select throws_ok(
  $$ update public.patient_profiles set org_id = '00000000-0000-0000-0000-00000000000b' where patient_id = '00000000-0000-0000-0000-0000000a1001' $$,
  '42501', null,
  'P3b denied: patient_a1 cannot move their own patient_profiles.org_id to org B'
);
select throws_ok(
  $$ insert into public.lab_reports (org_id, patient_id, report_type) values ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000a1001', 'x') $$,
  '42501', null,
  'P4 denied: patient_a1 cannot insert a lab_report into org B'
);
select throws_ok(
  $$ insert into public.consents (org_id, patient_id, consent_type, granted) values ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000a1001', 'x', true) $$,
  '42501', null,
  'P4b denied: patient_a1 cannot insert a consent into org B'
);

-- P5: read_only sees clinical detail - fixed by dropping read_only's SELECT
-- on patient_profiles/lab_reports/consents (H2). patients (list columns
-- only) is unaffected and still readable. TC-015 fix round (Leo ruling,
-- 28 Oct) supersedes H2 for lab_reports only (read_only needs it for the
-- identity_hold exclusion in its own-clinic detail/trend view); the other
-- two stay denied.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2');
select is(
  (select count(*) from public.lab_reports)::int, 1,
  'P5 allowed (fix round): read_only_a sees same-org lab_reports, no write'
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

-- P9 (review group C, C1): a staff member could create a patients row for
-- an arbitrary existing auth user id via a direct INSERT. Fixed by dropping
-- patients_staff_write_insert and replacing it with the
-- create_patient_record() RPC (not staff anywhere, no existing patients row
-- anywhere, aal2 + physician/care_coordinator, own org only, audited).
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select throws_ok(
  $$ insert into public.patients (id, org_id) values ('00000000-0000-0000-0000-0000000a9001', '00000000-0000-0000-0000-00000000000a') $$,
  '42501', null,
  'P9 denied: a staff member can no longer create a patients row via a direct INSERT (no policy left)'
);

-- Positive: physician_a creates a patient record for a9001 (a real,
-- never-bound auth user) through the RPC, and it's audited. audit_log has
-- zero client policies and revoked grants (090_audit_log.sql), so it's read
-- back as the pg_prove superuser, same pattern as 020_org_members.sql.
reset role;
select set_config('request.jwt.claims', '', true);
select is(
  (select count(*)::int from public.audit_log where event_type = 'patient_created' and target_user_id = '00000000-0000-0000-0000-0000000a9001'),
  0,
  'precondition: no prior patient_created audit row for a9001'
);
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select lives_ok(
  $$ select public.create_patient_record('00000000-0000-0000-0000-0000000a9001', 'Fictional Patient A9001', 'MRN-A9001') $$,
  'P9 RPC positive: physician_a can create a patient record for an unbound account via create_patient_record()'
);
select is(
  (select org_id from public.patients where id = '00000000-0000-0000-0000-0000000a9001'),
  '00000000-0000-0000-0000-00000000000a',
  'P9 RPC positive: the new patients row is bound to the caller''s own org'
);
reset role;
select set_config('request.jwt.claims', '', true);
select is(
  (select count(*)::int from public.audit_log where event_type = 'patient_created' and target_user_id = '00000000-0000-0000-0000-0000000a9001' and actor_user_id = '00000000-0000-0000-0000-0000000a0002'),
  1,
  'P9 RPC positive: create_patient_record() writes exactly one patient_created audit row'
);
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a

-- Negative: the target is already staff (physician_b) - refused, even
-- though physician_b is a real, existing auth user.
select throws_ok(
  $$ select public.create_patient_record('00000000-0000-0000-0000-0000000b0001') $$,
  '42501', null,
  'P9 RPC negative: cannot bind a patient record to an existing staff account'
);

-- Negative: the target already has a patients row (patient_a1).
select throws_ok(
  $$ select public.create_patient_record('00000000-0000-0000-0000-0000000a1001') $$,
  '42501', null,
  'P9 RPC negative: cannot create a second patients row for an account that already has one'
);

-- Negative: caller is read_only (not physician/care_coordinator).
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2'); -- read_only_a
select throws_ok(
  $$ select public.create_patient_record('00000000-0000-0000-0000-0000000a9001') $$,
  '42501', null,
  'P9 RPC negative: read_only cannot call create_patient_record()'
);

-- Negative: caller is physician but only at aal1.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal1'); -- physician_a
select throws_ok(
  $$ select public.create_patient_record('00000000-0000-0000-0000-0000000a9001') $$,
  '42501', null,
  'P9 RPC negative: create_patient_record() is rejected at aal1'
);

-- TC-011: refuse Zyndio platform_admins (not org_members, so prior staff check missed them).
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select throws_ok(
  $$ select public.create_patient_record('00000000-0000-0000-0000-0000000af001') $$,
  '42501', null,
  'TC-011: create_patient_record refuses platform_admins accounts'
);

select * from finish();
rollback;
