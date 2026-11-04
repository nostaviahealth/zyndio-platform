-- POR-06: per-patient export.
--
-- Proves: physician and care_coordinator can export (json and csv); read_only,
-- org_admin, aal1 and anon are refused with 42501 and write no audit row; an
-- invalid format is refused; other clinic / unknown id return null with no
-- audit row; identity-held results and any dose never leave; one
-- 'patient_record_exported' audit row per export with the format recorded.
-- Fixtures live in this transaction (UUIDs ...753...) and are rolled back.
begin;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);

insert into public.patient_treatments (org_id, patient_id, name, started_on, status, source) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'Example GLP-1 medication (fictional)', current_date - 90, 'Active', 'Fictional record');
insert into public.lab_reports (id, org_id, patient_id, report_type, data, identity_hold) values
  ('00000000-0000-0000-0000-000000753a01', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'metabolic_panel', '{}', false),
  ('00000000-0000-0000-0000-000000753a02', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'metabolic_panel', '{}', true);
insert into public.lab_results
  (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value, unit, status, range_high, taken_at) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-000000753a01', 'hba1c', 'HbA1c', 5.6, '%', 'within_range', 5.7, now() - interval '20 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-000000753a01', 'glucose_fasting', 'Glucose, fasting', 92, 'mg/dL', 'within_range', 99, now() - interval '20 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-000000753a02', 'triglycerides', 'Triglycerides', 400, 'mg/dL', 'outside_range', 150, now() - interval '5 days');

create temp table _x (k text primary key, v jsonb) on commit drop;
grant all on _x to authenticated;

-- ---------------------------------------------------------------------------
-- Allowed roles
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
insert into _x select 'json', public.export_patient_record('00000000-0000-0000-0000-0000000a1001', 'json');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2'); -- care_coordinator_a
insert into _x select 'csv', public.export_patient_record('00000000-0000-0000-0000-0000000a1001', 'CSV');

select is((select v #>> '{patient,mrn}' from _x where k = 'json'), 'MRN-A1', 'export carries the patient header');
select is((select (v ->> 'schema_version')::int from _x where k = 'json'), 1, 'schema_version 1');
select is((select jsonb_array_length(v -> 'lab_results') from _x where k = 'json'), 2, 'two lab results (held report excluded)');
select ok(not (select v::text from _x where k = 'json') ilike '%triglycerides%', 'identity-held results never leave');
select ok(not (select v::text from _x where k = 'json') ilike '%dose%', 'no dose in the export');
select is((select array_agg(k2 order by k2) from _x, jsonb_object_keys(v -> 'treatments' -> 0) k2 where k = 'json'),
  array['name', 'source', 'started_on', 'status'], 'treatment rows are the whitelisted columns only');
select is((select v ->> 'format' from _x where k = 'csv'), 'csv', 'care_coordinator csv export (format normalised)');

-- ---------------------------------------------------------------------------
-- Refused roles and inputs
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2'); -- read_only_a
select throws_ok($$ select public.export_patient_record('00000000-0000-0000-0000-0000000a1001', 'json') $$, '42501', null,
  'read_only is blocked from export');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select throws_ok($$ select public.export_patient_record('00000000-0000-0000-0000-0000000a1001', 'json') $$, '42501', null,
  'org_admin is blocked from export');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal1');
select throws_ok($$ select public.export_patient_record('00000000-0000-0000-0000-0000000a1001', 'json') $$, '42501', null,
  'aal1 is blocked from export');
select tests.authenticate_as_anon();
select throws_ok($$ select public.export_patient_record('00000000-0000-0000-0000-0000000a1001', 'json') $$, '42501', null,
  'anon is blocked from export');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select throws_ok($$ select public.export_patient_record('00000000-0000-0000-0000-0000000a1001', 'xml') $$, '22023', null,
  'unknown format refused');
select is(public.export_patient_record('00000000-0000-0000-0000-0000009e9e9e', 'json'), null, 'unknown id: null');
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2');
select is(public.export_patient_record('00000000-0000-0000-0000-0000000a1001', 'json'), null, 'other clinic: null');

-- ---------------------------------------------------------------------------
-- Audit
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', '', true);
select is((select count(*)::int from public.audit_log where event_type = 'patient_record_exported'
            and target_user_id = '00000000-0000-0000-0000-0000000a1001'), 2, 'exactly one audit row per successful export');
select is((select metadata ->> 'format' from public.audit_log where event_type = 'patient_record_exported'
            and actor_user_id = '00000000-0000-0000-0000-0000000a0002'), 'json', 'physician export audited as json');
select is((select metadata ->> 'format' from public.audit_log where event_type = 'patient_record_exported'
            and actor_user_id = '00000000-0000-0000-0000-0000000a0003'), 'csv', 'care_coordinator export audited as csv');
select is((select (metadata ->> 'lab_result_count')::int from public.audit_log where event_type = 'patient_record_exported'
            and actor_user_id = '00000000-0000-0000-0000-0000000a0002'), 2, 'audit row records the row count');
select is((select count(*)::int from public.audit_log where event_type = 'patient_record_exported'
            and actor_user_id in ('00000000-0000-0000-0000-0000000a0004', '00000000-0000-0000-0000-0000000a0001',
                                  '00000000-0000-0000-0000-0000000b0001')), 0, 'refused and not-found exports write no audit row');

select * from finish();
rollback;
