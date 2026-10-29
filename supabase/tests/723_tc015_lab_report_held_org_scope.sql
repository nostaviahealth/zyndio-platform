-- TC-015 fix round (28 Oct, Clara Low): public.lab_report_held(uuid) is a
-- SECURITY DEFINER helper, so it reads lab_reports past RLS. Before this fix
-- it answered for ANY report uuid in ANY clinic: false for another clinic's
-- non-held report, true for a held one or an unknown uuid - a cross-clinic
-- oracle on report existence and identity-hold state.
--
-- Fix: scope it to public.current_org_id() inside the function and keep it
-- failing CLOSED, so another clinic's report gives exactly the same answer as
-- a report that does not exist (true = held = hidden). The roster-summary
-- maintenance path (triggers / refresh_*, which run with no clinic session)
-- uses a separate, non-client-callable unscoped helper so the rollup stays
-- correct; the last block proves that path is unchanged.
--
-- FAILS on 14e1296 (cross-clinic answers are false, not true). Fixtures are in
-- this file's own transaction under ...723... UUIDs and rolled back.
begin;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);

insert into public.lab_reports (id, org_id, patient_id, report_type, data, identity_hold) values
  ('00000000-0000-0000-0000-00000723a001', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'metabolic_panel', '{}', false),
  ('00000000-0000-0000-0000-00000723a002', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'metabolic_panel', '{}', true),
  ('00000000-0000-0000-0000-00000723b001', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000b1001', 'metabolic_panel', '{}', false),
  ('00000000-0000-0000-0000-00000723b002', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000b1001', 'metabolic_panel', '{}', true);

-- physician_a (org A): own-clinic answers are real.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select is(public.lab_report_held('00000000-0000-0000-0000-00000723a001'), false,
  'physician_a: own-clinic non-held report -> false (visible)');
select is(public.lab_report_held('00000000-0000-0000-0000-00000723a002'), true,
  'physician_a: own-clinic held report -> true');
select is(public.lab_report_held('00000000-0000-0000-0000-00000723ffff'), true,
  'physician_a: unknown report uuid -> true (fail closed)');

-- Another clinic's report must be indistinguishable from an unknown uuid.
select is(public.lab_report_held('00000000-0000-0000-0000-00000723b001'), true,
  'physician_a: org-B NON-held report -> true, same as a report that does not exist');
select is(public.lab_report_held('00000000-0000-0000-0000-00000723b002'), true,
  'physician_a: org-B held report -> true, same as a report that does not exist');
select is(
  public.lab_report_held('00000000-0000-0000-0000-00000723b001'),
  public.lab_report_held('00000000-0000-0000-0000-00000723ffff'),
  'physician_a: org-B report answer == unknown-uuid answer (no cross-clinic oracle)'
);

-- And the mirror: physician_b (org B) learns nothing about org A.
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2');
select is(public.lab_report_held('00000000-0000-0000-0000-00000723a001'), true,
  'physician_b: org-A NON-held report -> true, same as a report that does not exist');
select is(public.lab_report_held('00000000-0000-0000-0000-00000723b001'), false,
  'physician_b: own-clinic non-held report -> false (visible)');

-- No clinic session at all (a patient, not an org member): every answer is closed.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(public.lab_report_held('00000000-0000-0000-0000-00000723a001'), true,
  'patient (no clinic membership): any report -> true (fail closed)');

select tests.authenticate_as_anon();
select throws_ok(
  $$select public.lab_report_held('00000000-0000-0000-0000-00000723a001')$$,
  '42501', null,
  'anon cannot execute lab_report_held()'
);

-- Regression guard: the roster-summary rollup (written by triggers with no
-- clinic session) still sees the real hold state of every clinic's reports.
reset role;
select set_config('request.jwt.claims', '', true);
insert into public.lab_results
  (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value, unit, status, taken_at) values
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000b1001', '00000000-0000-0000-0000-00000723b001',
   'hba1c', 'HbA1c', 6.0, '%', 'within_range', now() - interval '3 days');
select is(
  (select has_any_labs from public.patient_roster_summary
    where patient_id = '00000000-0000-0000-0000-0000000b1001'),
  true,
  'summary trigger (no clinic session): a result on a non-held org-B report still counts as a lab'
);
select is(
  (select has_identity_hold from public.patient_roster_summary
    where patient_id = '00000000-0000-0000-0000-0000000b1001'),
  false,
  'summary trigger (no clinic session): a non-held report is not flagged identity_hold'
);

select * from finish();
rollback;
