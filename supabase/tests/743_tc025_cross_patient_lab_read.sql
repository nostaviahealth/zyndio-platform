-- TC-025 C3: a patient can read their OWN lab results / biomarkers, and can
-- NEVER read another patient's - whether that other patient is in the SAME
-- clinic or in ANOTHER clinic - via a direct table read or any RPC exposed to
-- authenticated. Positive control: the patient sees their own rows, so a
-- blanket "deny everything" that also broke own-reads would be caught.
--
-- Lab / biomarker read surface (grep of supabase/migrations for
-- lab|biomarker|marker|result|report|analyte|reading|trend):
--   * public.lab_reports  - one row per uploaded report (TC-005; data jsonb +
--     identity_hold). Patient self-read is patient_id = auth.uid() AND
--     email-confirmed AND linked AND identity_hold = false. RLS forced.
--   * public.lab_results  - value-level analyte time series (TC-015). Patient
--     self-read is patient_id = auth.uid() AND own_lab_report_released
--     (the parent report is theirs and not identity-held). Staff path is
--     org+aal2 and still includes held rows. RLS forced.
--   RPCs exposed to authenticated that RETURN lab values:
--     - public.patient_trend(uuid,text,text)          SECURITY INVOKER
--     - public.patient_latest_results(uuid)           SECURITY INVOKER
--     Both run under the caller's RLS AND exclude held reports via
--     public.lab_report_held(), which is clinic-scoped. For a PATIENT (no
--     clinic) lab_report_held fails closed (true) for every report, so these
--     RPCs return NOTHING for a patient - for another patient's id AND for the
--     patient's own id. They are the staff trend/latest path (proven below by
--     a physician positive control), not a patient read path, and are not a
--     cross-patient leak vector. We assert the patient-call behaviour, the
--     staff positive control, and that both stay INVOKER.
--   Other authenticated-executable lab readers:
--     - public.lab_report_held(uuid)   SECURITY DEFINER, but clinic-scoped to
--       current_org_id(); a patient has no clinic, so it fails CLOSED (always
--       true) and is not a cross-patient existence/hold oracle. Asserted.
--     - public.open_patient_detail(uuid) SECURITY INVOKER + role-gated to
--       physician/care_coordinator; a patient gets NULL. (Returns treatment
--       context, not labs; checked here only as a non-leak.)
--
-- Structural guard (enumerated like C2/742): the set of SECURITY DEFINER,
-- authenticated-executable, non-trigger functions that read lab_reports/
-- lab_results is pinned to a reviewed allowlist, so a future definer RPC that
-- reads labs past RLS can't be added without failing this test and being
-- reviewed. We also pin patient_trend/patient_latest_results to INVOKER.
begin;
select no_plan();

-- ---------------------------------------------------------------------------
-- Fixtures (TC-025 namespace, rolled back at the end). Reader = patient a1001
-- (clinic A, linked + confirmed in global fixtures). Same-clinic victim =
-- a6002 (clinic A; has an auth.users row globally but no patients row, so we
-- add one here). Other-clinic victim = b1001 (clinic B).
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', '', true);

insert into public.patients (id, org_id, display_name, mrn) values
  ('00000000-0000-0000-0000-0000000a6002', '00000000-0000-0000-0000-00000000000a', 'Fictional Patient A2', 'MRN-A2');

insert into public.lab_reports (id, org_id, patient_id, report_type, data, identity_hold) values
  ('00000000-0000-0000-0000-00000025a301', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'metabolic_panel', '{}', false), -- reader A own
  ('00000000-0000-0000-0000-00000025a302', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a6002', 'metabolic_panel', '{}', false), -- same-clinic victim
  ('00000000-0000-0000-0000-00000025b301', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000b1001', 'metabolic_panel', '{}', false); -- other-clinic victim

insert into public.lab_results
  (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value, unit, status, taken_at) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000025a301', 'hba1c', 'HbA1c', 5.4, '%', 'within_range', now() - interval '10 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000025a301', 'hba1c', 'HbA1c', 5.5, '%', 'within_range', now() - interval '40 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a6002', '00000000-0000-0000-0000-00000025a302', 'hba1c', 'HbA1c', 6.3, '%', 'outside_range', now() - interval '10 days'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000b1001', '00000000-0000-0000-0000-00000025b301', 'hba1c', 'HbA1c', 6.1, '%', 'within_range', now() - interval '10 days');

-- ---------------------------------------------------------------------------
-- Act as patient A1 (clinic A, reads their own labs only).
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');

-- Positive controls: A sees A's own rows (a deny-all regression would trip here).
select is(
  (select count(*) from public.lab_results
     where lab_report_id = '00000000-0000-0000-0000-00000025a301')::int,
  2,
  'patient A1 CAN read their own lab_results (positive control)'
);
select is(
  (select count(*) from public.lab_reports
     where id = '00000000-0000-0000-0000-00000025a301')::int,
  1,
  'patient A1 CAN read their own lab_reports row (positive control)'
);
-- patient_trend / patient_latest_results are the STAFF trend path: they filter
-- out held reports via lab_report_held(), which is clinic-scoped through
-- current_org_id() (org_members). A patient has no org_members row, so every
-- report counts as held and both RPCs return nothing for a patient - even for
-- their own id. That is fail-closed (not a leak); the staff positive control
-- further down proves the RPCs do return rows, so the zeros are not vacuous.
select is(
  (select count(*) from public.patient_trend(
     '00000000-0000-0000-0000-0000000a1001', 'hba1c', 'ALL'))::int,
  0,
  'patient_trend for the patient''s own id fails closed (staff path, no patient rows)'
);
select is(
  (select count(*) from public.patient_latest_results(
     '00000000-0000-0000-0000-0000000a1001'))::int,
  0,
  'patient_latest_results for the patient''s own id fails closed (staff path)'
);

-- ── Same-clinic isolation: A cannot read a6002 (also clinic A) ──
select is(
  (select count(*) from public.lab_results
     where patient_id = '00000000-0000-0000-0000-0000000a6002')::int,
  0,
  'patient A1 cannot read same-clinic patient a6002 lab_results'
);
select is(
  (select count(*) from public.lab_reports
     where patient_id = '00000000-0000-0000-0000-0000000a6002')::int,
  0,
  'patient A1 cannot read same-clinic patient a6002 lab_reports'
);
select is(
  (select count(*) from public.patient_trend(
     '00000000-0000-0000-0000-0000000a6002', 'hba1c', 'ALL'))::int,
  0,
  'patient_trend(same-clinic a6002) returns nothing for patient A1'
);
select is(
  (select count(*) from public.patient_latest_results(
     '00000000-0000-0000-0000-0000000a6002'))::int,
  0,
  'patient_latest_results(same-clinic a6002) returns nothing for patient A1'
);

-- ── Cross-clinic isolation: A cannot read b1001 (clinic B) ──
select is(
  (select count(*) from public.lab_results
     where patient_id = '00000000-0000-0000-0000-0000000b1001')::int,
  0,
  'patient A1 cannot read other-clinic patient b1001 lab_results'
);
select is(
  (select count(*) from public.lab_reports
     where patient_id = '00000000-0000-0000-0000-0000000b1001')::int,
  0,
  'patient A1 cannot read other-clinic patient b1001 lab_reports'
);
select is(
  (select count(*) from public.patient_trend(
     '00000000-0000-0000-0000-0000000b1001', 'hba1c', 'ALL'))::int,
  0,
  'patient_trend(other-clinic b1001) returns nothing for patient A1'
);
select is(
  (select count(*) from public.patient_latest_results(
     '00000000-0000-0000-0000-0000000b1001'))::int,
  0,
  'patient_latest_results(other-clinic b1001) returns nothing for patient A1'
);

-- lab_report_held: a patient has no clinic, so it fails CLOSED (true) for every
-- report id - own, same-clinic, other-clinic, unknown - so it leaks neither
-- existence nor real hold state across patients.
select is(
  (select public.lab_report_held('00000000-0000-0000-0000-00000025b301')),
  true,
  'lab_report_held(other-clinic report) fails closed (true) for a patient - no oracle'
);
select is(
  (select public.lab_report_held('00000000-0000-0000-0000-00000025a302')),
  true,
  'lab_report_held(same-clinic other-patient report) fails closed (true) for a patient'
);

-- open_patient_detail is role-gated: a patient gets NULL for anyone, incl. self.
select is(
  (select public.open_patient_detail('00000000-0000-0000-0000-0000000a6002')),
  null,
  'open_patient_detail returns null to a patient (role-gated, no leak)'
);

-- ---------------------------------------------------------------------------
-- Staff positive control: physician A (clinic A) gets A1's series through the
-- same RPCs, and nothing for the clinic-B patient. Proves the RPCs work, so
-- the patient zeros above are isolation, not a broken fixture.
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select is(
  (select count(*) from public.patient_trend(
     '00000000-0000-0000-0000-0000000a1001', 'hba1c', 'ALL'))::int,
  2,
  'physician A trend for clinic-A patient A1 returns the series (positive control)'
);
select is(
  (select count(*) from public.patient_latest_results(
     '00000000-0000-0000-0000-0000000a1001'))::int,
  1,
  'physician A latest-results for clinic-A patient A1 returns one row (positive control)'
);
select is(
  (select count(*) from public.patient_trend(
     '00000000-0000-0000-0000-0000000b1001', 'hba1c', 'ALL'))::int,
  0,
  'physician A gets nothing from patient_trend for clinic-B patient b1001'
);

-- ---------------------------------------------------------------------------
-- Structural guards (run as superuser; role switch is irrelevant to catalog
-- reads but reset to be explicit).
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', '', true);

-- The lab-reading functions authenticated can EXECUTE that are SECURITY
-- DEFINER (i.e. read past RLS) and are directly callable (not triggers) must
-- stay exactly this reviewed allowlist. lab_report_held is clinic-scoped +
-- fails closed (asserted above); flag_lab_report_needs_review is a role-gated
-- staff write that returns no lab values. Anything new here must be reviewed.
select is(
  (select coalesce(array_agg((n.nspname || '.' || pr.proname)::text order by (n.nspname || '.' || pr.proname)::text), array[]::text[])
   from pg_proc pr
   join pg_namespace n on n.oid = pr.pronamespace
   where n.nspname not in ('pg_catalog','information_schema','extensions','pgtap','tests')
     and has_function_privilege('authenticated', pr.oid, 'execute')
     and pr.prosecdef
     and pr.prorettype <> 'pg_catalog.trigger'::regtype
     and (pr.prosrc ~* 'lab_results' or pr.prosrc ~* 'lab_reports')),
  array[
    'public.flag_lab_report_needs_review',
    'public.lab_report_held',
    'public.own_lab_file_released',
    'public.own_lab_report_released'
  ]::text[],
  'only the reviewed SECURITY DEFINER lab readers are authenticated-executable'
);

-- The value-returning trend RPCs must stay SECURITY INVOKER so patient RLS
-- binds them (a flip to definer would bypass the isolation asserted above).
select is(
  (select coalesce(array_agg(pr.proname::text order by pr.proname::text), array[]::text[])
   from pg_proc pr
   join pg_namespace n on n.oid = pr.pronamespace
   where n.nspname = 'public'
     and pr.proname in ('patient_trend', 'patient_latest_results')
     and pr.prosecdef),
  array[]::text[],
  'patient_trend and patient_latest_results are SECURITY INVOKER (not definer)'
);

select * from finish();
rollback;
