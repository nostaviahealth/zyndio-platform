-- TC-030 item 8 (Henry, 2 Nov 2026 12:24; Clara PR #26 M2): create_patient_record
-- is care_coordinator-only. Fails on the pre-TC-030 definition, where a
-- physician could create a patient (the first assertion lived instead of
-- throwing). a9001 ("spare-xorg@example.test", 000_fixtures.sql) is a real,
-- never-bound, non-self-signup auth user at the start of this transaction.
begin;
select no_plan();

-- A physician at aal2 is now REFUSED (role gate), and leaves no patient row.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select throws_ok(
  $$ select public.create_patient_record('00000000-0000-0000-0000-0000000a9001', 'Fictional Patient A9001', 'MRN-A9001') $$,
  '42501', null,
  'TC-030: a physician can no longer create a patient via create_patient_record() - care_coordinator only'
);
reset role;
select set_config('request.jwt.claims', '', true);
select is(
  (select count(*)::int from public.patients where id = '00000000-0000-0000-0000-0000000a9001'),
  0,
  'TC-030: the refused physician attempt created no patient row'
);

-- A care_coordinator at aal2 CAN create, in their own org, audited, with the
-- active clinic-provisioned link.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2'); -- care_coordinator_a
select lives_ok(
  $$ select public.create_patient_record('00000000-0000-0000-0000-0000000a9001', 'Fictional Patient A9001', 'MRN-A9001') $$,
  'TC-030: a care_coordinator can create a patient via create_patient_record()'
);
select is(
  (select org_id from public.patients where id = '00000000-0000-0000-0000-0000000a9001'),
  '00000000-0000-0000-0000-00000000000a',
  'TC-030: the new patients row is bound to the coordinator''s own org'
);
reset role;
select set_config('request.jwt.claims', '', true);
-- Count the link AFTER reset role: patient_record_links' only RLS policy is
-- app_user_id = auth.uid(), so as the still-authenticated coordinator the row
-- is invisible (count 0) even though it exists. As postgres it is visible.
select is(
  (select count(*)::int from public.patient_record_links
     where app_user_id = '00000000-0000-0000-0000-0000000a9001' and status = 'active'),
  1,
  'TC-030: create_patient_record still writes the active clinic-provisioned link'
);
select is(
  (select count(*)::int from public.audit_log
     where event_type = 'patient_created'
       and target_user_id = '00000000-0000-0000-0000-0000000a9001'
       and actor_user_id = '00000000-0000-0000-0000-0000000a0003'),
  1,
  'TC-030: the coordinator''s create_patient_record() writes exactly one patient_created audit row'
);

-- read_only is refused.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2'); -- read_only_a
select throws_ok(
  $$ select public.create_patient_record('00000000-0000-0000-0000-0000000a6002') $$,
  '42501', null,
  'TC-030: read_only cannot call create_patient_record()'
);

-- org_admin is refused (admins manage users only).
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select throws_ok(
  $$ select public.create_patient_record('00000000-0000-0000-0000-0000000a6002') $$,
  '42501', null,
  'TC-030: org_admin cannot call create_patient_record()'
);

-- A care_coordinator only at aal1 is refused (step-up still required).
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal1'); -- care_coordinator_a, aal1
select throws_ok(
  $$ select public.create_patient_record('00000000-0000-0000-0000-0000000a6002') $$,
  '42501', null,
  'TC-030: create_patient_record() is still rejected at aal1, even for a coordinator'
);

select * from finish();
rollback;
