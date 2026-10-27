-- TC-015 slice 1 (physician list + detail), fail-first RLS isolation.
--
-- Leo's ruling R1 (Henry 26 Oct): read_only may SELECT the roster (patients +
-- roster RPC columns) but gets NO lab_results / trend / detail. Its detail
-- open returns not-found (identical to unknown id / other clinic) - never a
-- distinct "forbidden". Physician + care_coordinator (same org, aal2) get the
-- list and the detail. Another clinic's patient is invisible everywhere.
--
-- Fixtures are built inside this file's own transaction (as the pg_prove
-- superuser, before authenticate_as) with TC-015-namespaced UUIDs, and rolled
-- back at the end, so nothing leaks into the shared 000_fixtures state or
-- other test files. Expect this file to FAIL until the schema, RLS and RPCs
-- land (public.lab_results / patient_treatments / patient_roster_meta,
-- physician_patient_roster, patient_trend, open_patient_detail).
begin;
select no_plan();

-- ---------------------------------------------------------------------------
-- Fixtures: a visible report + results for org A patient a1001, and a report +
-- results for org B patient b1001, plus roster meta for both.
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', '', true);

insert into public.lab_reports (id, org_id, patient_id, report_type, data, identity_hold) values
  ('00000000-0000-0000-0000-00000015a301', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'metabolic_panel', '{}', false),
  ('00000000-0000-0000-0000-00000015b301', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000b1001', 'metabolic_panel', '{}', false);

insert into public.lab_results
  (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value, unit, status, taken_at) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000015a301', 'hba1c', 'HbA1c', 5.5, '%', 'within_range', now() - interval '20 days'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000b1001', '00000000-0000-0000-0000-00000015b301', 'hba1c', 'HbA1c', 6.1, '%', 'within_range', now() - interval '20 days');

insert into public.patient_treatments (org_id, patient_id, name, started_on, status, source) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'Example GLP-1 medication (fictional)', date '2026-04-02', 'Active', 'Zyndio record, Oct 20, 2026');

insert into public.patient_roster_meta (patient_id, org_id, sex, birth_date, program_started_on, last_activity_at) values
  ('00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000000000a', 'F', date '1985-03-01', date '2026-04-02', now()),
  ('00000000-0000-0000-0000-0000000b1001', '00000000-0000-0000-0000-00000000000b', 'M', date '1970-01-01', date '2026-08-01', now());

-- ---------------------------------------------------------------------------
-- physician_a (same org): sees the list + detail for a1001, nothing for org B.
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a

select is(
  (select count(*) from public.lab_results where org_id = '00000000-0000-0000-0000-00000000000b')::int,
  0,
  'physician_a cannot see org B lab_results (cross-org denied)'
);
select is(
  (select count(*) from public.lab_results where patient_id = '00000000-0000-0000-0000-0000000a1001')::int,
  1,
  'physician_a sees their own org patient a1001 lab_results'
);

select is(
  (select count(*) from public.physician_patient_roster(null, 'all', 'recent', 50, 0)
    where patient_id = '00000000-0000-0000-0000-0000000a1001')::int,
  1,
  'physician_a roster includes same-org patient a1001'
);
select is(
  (select count(*) from public.physician_patient_roster(null, 'all', 'recent', 50, 0)
    where patient_id = '00000000-0000-0000-0000-0000000b1001')::int,
  0,
  'physician_a roster never includes org B patient b1001'
);

select isnt(
  (select public.open_patient_detail('00000000-0000-0000-0000-0000000a1001')),
  null,
  'physician_a can open a1001 detail'
);
select is(
  (select public.open_patient_detail('00000000-0000-0000-0000-0000000b1001')),
  null,
  'physician_a opening org B patient returns not-found (null), same as unknown'
);
select is(
  (select public.open_patient_detail('00000000-0000-0000-0000-0000009e9e9e')),
  null,
  'physician_a opening an unknown patient id returns not-found (null)'
);

select is(
  (select count(*) from public.patient_trend('00000000-0000-0000-0000-0000000a1001', 'hba1c', 'ALL'))::int,
  1,
  'physician_a gets trend points for a1001'
);
select is(
  (select count(*) from public.patient_trend('00000000-0000-0000-0000-0000000b1001', 'hba1c', 'ALL'))::int,
  0,
  'physician_a gets no trend points for org B patient b1001'
);

-- ---------------------------------------------------------------------------
-- care_coordinator_a (same org): also gets the list + detail + trend.
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2'); -- care_coordinator_a
select isnt(
  (select public.open_patient_detail('00000000-0000-0000-0000-0000000a1001')),
  null,
  'care_coordinator_a can open a1001 detail'
);
select is(
  (select count(*) from public.patient_trend('00000000-0000-0000-0000-0000000a1001', 'hba1c', 'ALL'))::int,
  1,
  'care_coordinator_a gets trend points for a1001'
);

-- ---------------------------------------------------------------------------
-- read_only_a: roster YES; lab_results / trend / detail NO (not-found).
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2'); -- read_only_a
select is(
  (select count(*) from public.physician_patient_roster(null, 'all', 'recent', 50, 0)
    where patient_id = '00000000-0000-0000-0000-0000000a1001')::int,
  1,
  'read_only_a CAN see the roster row for a1001'
);
select is(
  (select count(*) from public.lab_results)::int,
  0,
  'read_only_a sees no lab_results rows at all (no clinical detail)'
);
select is(
  (select public.open_patient_detail('00000000-0000-0000-0000-0000000a1001')),
  null,
  'read_only_a opening a1001 detail returns not-found (null), same as unknown'
);
select is(
  (select count(*) from public.patient_trend('00000000-0000-0000-0000-0000000a1001', 'hba1c', 'ALL'))::int,
  0,
  'read_only_a gets no trend points'
);

-- ---------------------------------------------------------------------------
-- physician_b (other clinic): no visibility into org A anywhere.
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2'); -- physician_b
select is(
  (select count(*) from public.lab_results where patient_id = '00000000-0000-0000-0000-0000000a1001')::int,
  0,
  'physician_b cannot direct-select a1001 lab_results'
);
select is(
  (select public.open_patient_detail('00000000-0000-0000-0000-0000000a1001')),
  null,
  'physician_b opening a1001 detail returns not-found (null), same as unknown'
);
select is(
  (select count(*) from public.patient_trend('00000000-0000-0000-0000-0000000a1001', 'hba1c', 'ALL'))::int,
  0,
  'physician_b gets no trend points for org A patient a1001'
);

select * from finish();
rollback;
