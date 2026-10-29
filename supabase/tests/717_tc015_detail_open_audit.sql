-- TC-015 slice 1, fail-first audit on detail open (Leo ruling 4).
--
-- open_patient_detail(p_patient_id) writes exactly ONE audit row
-- ('patient_detail_opened', actor, patient, time) per successful open, via the
-- existing write_audit_log path - and writes NONE for an invisible patient
-- (other clinic / unknown id return not-found with no row). read_only is now
-- a legitimate same-clinic open (Leo ruling, fix round 28 Oct): it IS audited,
-- same as physician/care_coordinator.
--
-- Fixtures live in this transaction only, rolled back. Expect FAIL until the
-- schema + open_patient_detail land.
begin;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);

insert into public.lab_reports (id, org_id, patient_id, report_type, data, identity_hold) values
  ('00000000-0000-0000-0000-00000015a301', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'metabolic_panel', '{}', false);
insert into public.lab_results
  (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value, unit, status, taken_at) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000015a301', 'hba1c', 'HbA1c', 5.5, '%', 'within_range', now() - interval '20 days');

-- ----- physician_a: one row per call -----
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select lives_ok(
  $$ select public.open_patient_detail('00000000-0000-0000-0000-0000000a1001') $$,
  'open_patient_detail succeeds for a visible patient'
);

reset role;
select set_config('request.jwt.claims', '', true);
select is(
  (select count(*)::int from public.audit_log
    where event_type = 'patient_detail_opened'
      and actor_user_id = '00000000-0000-0000-0000-0000000a0002'
      and target_user_id = '00000000-0000-0000-0000-0000000a1001'
      and org_id = '00000000-0000-0000-0000-00000000000a'),
  1,
  'exactly one patient_detail_opened row after one open (actor, patient, org recorded)'
);

-- second call writes exactly one more row
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select public.open_patient_detail('00000000-0000-0000-0000-0000000a1001');
reset role;
select set_config('request.jwt.claims', '', true);
select is(
  (select count(*)::int from public.audit_log
    where event_type = 'patient_detail_opened'
      and target_user_id = '00000000-0000-0000-0000-0000000a1001'),
  2,
  'a second open writes exactly one more row (one audit row per call)'
);

-- ----- invisible patients: no row at all -----
-- cross-org (physician_b opening org A patient)
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2'); -- physician_b
select public.open_patient_detail('00000000-0000-0000-0000-0000000a1001');
-- unknown id
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select public.open_patient_detail('00000000-0000-0000-0000-0000009e9e9e');

reset role;
select set_config('request.jwt.claims', '', true);
select is(
  (select count(*)::int from public.audit_log
    where event_type = 'patient_detail_opened'
      and actor_user_id = '00000000-0000-0000-0000-0000000b0001'),
  0,
  'cross-org open writes no patient_detail_opened row'
);
select is(
  (select count(*)::int from public.audit_log
    where event_type = 'patient_detail_opened'
      and target_user_id = '00000000-0000-0000-0000-0000009e9e9e'),
  0,
  'unknown-id open writes no patient_detail_opened row'
);

-- ----- read_only_a: a legitimate open, audited exactly once; twice -> two rows -----
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2'); -- read_only_a
select public.open_patient_detail('00000000-0000-0000-0000-0000000a1001');
reset role;
select set_config('request.jwt.claims', '', true);
select is(
  (select count(*)::int from public.audit_log
    where event_type = 'patient_detail_opened'
      and actor_user_id = '00000000-0000-0000-0000-0000000a0004'
      and target_user_id = '00000000-0000-0000-0000-0000000a1001'
      and org_id = '00000000-0000-0000-0000-00000000000a'),
  1,
  'read_only_a open writes exactly one patient_detail_opened row'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2'); -- read_only_a
select public.open_patient_detail('00000000-0000-0000-0000-0000000a1001');
reset role;
select set_config('request.jwt.claims', '', true);
select is(
  (select count(*)::int from public.audit_log
    where event_type = 'patient_detail_opened'
      and actor_user_id = '00000000-0000-0000-0000-0000000a0004'
      and target_user_id = '00000000-0000-0000-0000-0000000a1001'),
  2,
  'a second read_only_a open writes exactly one more row'
);

select * from finish();
rollback;
