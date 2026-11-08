-- ---------------------------------------------------------------------------
-- APP-05: the lab pipeline schema (20261105130000_app05_lab_pipeline.sql).
--   * lab_analyte_loinc: the reviewed starting codes; readable by signed-in
--     users only; no client writes; one alias can't map to two analytes.
--   * lab_reports.file_sha256: one report per file per patient (dedupe), hex
--     only; extraction_status values.
--   * lab_pipeline_file_results(): service_role only; files results with the
--     report's own org/patient/collection date; replaces (never doubles) on
--     re-run; never clears an identity hold; refuses a mapping that isn't in
--     the reviewed table; held results stay out of trends.
-- Fictional data only. Fixture actors from 000_fixtures.sql: patient A1
-- a1001 (clinic A, linked), patient B1 b1001 (clinic B), physician A a0002.
-- ---------------------------------------------------------------------------
begin;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);

-- ---------------------------------------------------------------------------
-- Reviewed LOINC table
-- ---------------------------------------------------------------------------

select is(
  (select jsonb_object_agg(analyte_key, loinc) from public.lab_analyte_loinc),
  '{"hba1c":"4548-4","glucose_fasting":"1558-6","insulin_fasting":"20448-7","triglycerides":"2571-8",
    "cholesterol_total":"2093-3","ldl_c_calc":"13457-7","ldl_c_direct":"18262-6","hdl_c":"2085-9",
    "non_hdl_c":"43396-1","apob":"1884-6","lpa":"10835-7","hscrp":"30522-7","alt":"1742-6","ast":"1920-8",
    "ggt":"2324-2","creatinine":"2160-0","egfr":"98979-8","tsh":"3016-3","ft4":"3024-7","ft3":"3051-0",
    "testosterone":"2986-8","estradiol":"2243-4","shbg":"13967-5","vitamin_d":"62292-8","ferritin":"2276-4",
    "igf1":"2484-4"}'::jsonb,
  'lab_analyte_loinc holds exactly the APP-05 starting codes');

select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid = 'public.lab_analyte_loinc'::regclass),
  'lab_analyte_loinc has RLS enabled and forced');

select throws_ok($$ insert into public.lab_analyte_loinc (analyte_key, display_name, loinc, canonical_unit, aliases, reviewed_by, reviewed_on)
                    values ('a1c_dup', 'Dup', '99999-9', '%', array['Hemoglobin A1C'], 'test', '2026-11-04') $$,
  '23505', null, 'an alias already used by another analyte (case/punctuation-insensitive) is refused');

select tests.authenticate_as_anon();
select throws_ok($$ select count(*) from public.lab_analyte_loinc $$, '42501', null, 'anon cannot read the LOINC table');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1');
select is((select count(*)::int from public.lab_analyte_loinc), 26, 'a signed-in patient can read the LOINC table');
select throws_ok($$ insert into public.lab_analyte_loinc (analyte_key, display_name, loinc, canonical_unit, reviewed_by, reviewed_on)
                    values ('x', 'x', '1-1', 'x', 'x', '2026-11-04') $$, '42501', null, 'clients cannot add a mapping');
select throws_ok($$ update public.lab_analyte_loinc set loinc = '1-1' where analyte_key = 'hba1c' $$, '42501', null, 'clients cannot change a mapping');
select throws_ok($$ delete from public.lab_analyte_loinc $$, '42501', null, 'clients cannot delete mappings');

-- ---------------------------------------------------------------------------
-- lab_reports: SHA-256 dedupe
-- ---------------------------------------------------------------------------

-- Patient A1 files a report with a file hash (as the app does).
select lives_ok($$ insert into public.lab_reports (id, org_id, patient_id, report_type, data, file_sha256) values
  ('00000000-0000-0000-0000-00000051a301', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001',
   'patient_upload', '{"title":"Fictional panel"}', repeat('ab', 32)) $$,
  'a patient files a report with its file SHA-256');
select throws_ok($$ insert into public.lab_reports (org_id, patient_id, report_type, data, file_sha256) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'patient_upload', '{}', repeat('ab', 32)) $$,
  '23505', null, 'the same file again for the same patient is refused (dedupe)');
select throws_ok($$ insert into public.lab_reports (org_id, patient_id, report_type, data, file_sha256) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'patient_upload', '{}', repeat('AB', 32)) $$,
  '23514', null, 'file_sha256 must be lower-case hex');
select throws_ok($$ insert into public.lab_reports (org_id, patient_id, report_type, data, extraction_status) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'patient_upload', '{}', 'done') $$,
  '23514', null, 'extraction_status is a closed list');
select is((select extraction_status from public.lab_reports where id = '00000000-0000-0000-0000-00000051a301'), 'pending',
  'a new report starts pending');

-- A different patient may have the same file (the key is per patient).
reset role;
select set_config('request.jwt.claims', '', true);
select lives_ok($$ insert into public.lab_reports (org_id, patient_id, report_type, data, file_sha256) values
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000b1001', 'patient_upload', '{}', repeat('ab', 32)) $$,
  'the same file for another patient is a separate report');

-- ---------------------------------------------------------------------------
-- lab_pipeline_file_results(): who can call it
-- ---------------------------------------------------------------------------

select ok(not has_function_privilege('authenticated', 'public.lab_pipeline_file_results(uuid, jsonb, jsonb)', 'EXECUTE'),
  'authenticated cannot execute lab_pipeline_file_results');
select ok(not has_function_privilege('anon', 'public.lab_pipeline_file_results(uuid, jsonb, jsonb)', 'EXECUTE'),
  'anon cannot execute lab_pipeline_file_results');
select ok(has_function_privilege('service_role', 'public.lab_pipeline_file_results(uuid, jsonb, jsonb)', 'EXECUTE'),
  'service_role can execute lab_pipeline_file_results');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1');
select throws_ok($$ select public.lab_pipeline_file_results('00000000-0000-0000-0000-00000051a301', '{}', '[]') $$,
  '42501', null, 'the patient cannot file results for their own report');

-- ---------------------------------------------------------------------------
-- Filing
-- ---------------------------------------------------------------------------

reset role;
select set_config('request.jwt.claims', '', true);

create temp table app05_payload as select
  jsonb_build_object(
    'file_sha256', repeat('ab', 32), 'extraction_status', 'extracted', 'identity_hold', false,
    'collected_on', '2026-10-14', 'lab_name', 'Fictional Reference Lab',
    'data', jsonb_build_object('markers', '[]'::jsonb, 'summary', 'Fictional', 'analyzed_at', '2026-11-04T00:00:00Z')) as report,
  jsonb_build_array(
    jsonb_build_object('analyte_key', 'hba1c', 'analyte_label', 'HbA1c', 'loinc', '4548-4', 'is_unmapped', false,
      'value', 5.5, 'unit', '%', 'status', 'within_range', 'range_high', 5.7, 'reported_name', 'Hemoglobin A1c',
      'reported_value', '37', 'reported_unit', 'mmol/mol', 'conversion_kind', 'hba1c', 'conversion_factor', 10.929,
      'reference_range_text', '<39', 'field_confidence', '{"analyte":0.97,"value":0.97}'::jsonb, 'confidence', 0.97,
      'review_reasons', '[]'::jsonb),
    jsonb_build_object('analyte_key', 'insulin_fasting', 'analyte_label', 'Fasting insulin', 'loinc', '20448-7', 'is_unmapped', false,
      'value', 9.4, 'unit', 'uIU/mL', 'status', 'no_range', 'reported_value', '56.4', 'reported_unit', 'pmol/L',
      'conversion_kind', 'divide', 'conversion_factor', 6.0, 'confidence', 0.97, 'review_reasons', '[]'::jsonb),
    jsonb_build_object('analyte_key', 'unmapped:lp_pla2_activity', 'analyte_label', 'Lp-PLA2 Activity', 'loinc', null, 'is_unmapped', true,
      'value', 180, 'unit', 'nmol/min/mL', 'status', 'needs_review', 'reported_value', '180', 'reported_unit', 'nmol/min/mL',
      'confidence', 0.6, 'review_reasons', '["low_confidence:value"]'::jsonb)
  ) as results;
grant select on app05_payload to service_role, authenticated;

select tests.authenticate_as_service_role();

select is(public.lab_pipeline_file_results('00000000-0000-0000-0000-00000051a301',
            (select report from app05_payload), (select results from app05_payload)), 3,
  'service_role files three results');

select results_eq(
  $$ select analyte_key, loinc, value, unit, reported_value, reported_unit, conversion_kind, conversion_factor,
            org_id, patient_id, taken_at
       from public.lab_results where lab_report_id = '00000000-0000-0000-0000-00000051a301' order by analyte_key $$,
  $$ values
     ('hba1c'::text, '4548-4'::text, 5.5::numeric, '%'::text, '37'::text, 'mmol/mol'::text, 'hba1c'::text, 10.929::numeric,
      '00000000-0000-0000-0000-00000000000a'::uuid, '00000000-0000-0000-0000-0000000a1001'::uuid, '2026-10-14 12:00:00+00'::timestamptz),
     ('insulin_fasting', '20448-7', 9.4, 'uIU/mL', '56.4', 'pmol/L', 'divide', 6.0,
      '00000000-0000-0000-0000-00000000000a'::uuid, '00000000-0000-0000-0000-0000000a1001'::uuid, '2026-10-14 12:00:00+00'::timestamptz),
     ('unmapped:lp_pla2_activity', null, 180, 'nmol/min/mL', '180', 'nmol/min/mL', null, null,
      '00000000-0000-0000-0000-00000000000a'::uuid, '00000000-0000-0000-0000-0000000a1001'::uuid, '2026-10-14 12:00:00+00'::timestamptz) $$,
  'results keep the as-reported value, unit and factor; org, patient and date come from the report');

select results_eq(
  $$ select extraction_status, collected_on, lab_name, identity_hold, data ->> 'title', data ->> 'summary'
       from public.lab_reports where id = '00000000-0000-0000-0000-00000051a301' $$,
  $$ values ('extracted'::text, '2026-10-14'::date, 'Fictional Reference Lab'::text, false, 'Fictional panel'::text, 'Fictional'::text) $$,
  'the report is updated and its existing data payload is kept (merged)');

-- Re-run: replaced, never doubled.
select is(public.lab_pipeline_file_results('00000000-0000-0000-0000-00000051a301',
            (select report from app05_payload), (select results from app05_payload)), 3, 're-filing files the same three');
select is((select count(*)::int from public.lab_results where lab_report_id = '00000000-0000-0000-0000-00000051a301'), 3,
  're-filing replaces the results (no double count)');

-- An identity hold is set by the pipeline but never cleared by it.
select public.lab_pipeline_file_results('00000000-0000-0000-0000-00000051a301',
  (select report || '{"identity_hold": true, "extraction_status": "identity_hold"}' from app05_payload), (select results from app05_payload));
select ok((select identity_hold from public.lab_reports where id = '00000000-0000-0000-0000-00000051a301'), 'the pipeline can hold a report');
select public.lab_pipeline_file_results('00000000-0000-0000-0000-00000051a301',
  (select report from app05_payload), (select results from app05_payload));
select ok((select identity_hold from public.lab_reports where id = '00000000-0000-0000-0000-00000051a301'),
  'a later run with a matching identity does not clear the hold');
select ok(public.lab_report_held('00000000-0000-0000-0000-00000051a301'),
  'the held report is excluded by lab_report_held() (trends / latest results)');

-- Refusals leave the previous results in place.
select throws_ok($$ select public.lab_pipeline_file_results('00000000-0000-0000-0000-00000051a301',
    (select report from app05_payload),
    jsonb_build_array(jsonb_build_object('analyte_key', 'hba1c', 'analyte_label', 'HbA1c', 'loinc', '2345-7', 'is_unmapped', false,
      'value', 5.5, 'unit', '%', 'status', 'within_range', 'review_reasons', '[]'::jsonb))) $$,
  '23514', null, 'a mapped result whose LOINC is not the reviewed one is refused');
select throws_ok($$ select public.lab_pipeline_file_results('00000000-0000-0000-0000-00000051a301',
    (select report from app05_payload),
    jsonb_build_array(jsonb_build_object('analyte_key', 'unmapped:x', 'analyte_label', 'X', 'loinc', '4548-4', 'is_unmapped', true,
      'value', 1, 'status', 'no_range', 'review_reasons', '[]'::jsonb))) $$,
  '23514', null, 'an unmapped result cannot carry a LOINC');
select throws_ok($$ select public.lab_pipeline_file_results('00000000-0000-0000-0000-00000051a301',
    (select report from app05_payload),
    jsonb_build_array(jsonb_build_object('analyte_key', 'apob', 'analyte_label', 'ApoB', 'loinc', '1884-6', 'is_unmapped', false,
      'value', 106, 'status', 'no_range', 'conversion_kind', 'multiply', 'conversion_factor', 0, 'review_reasons', '[]'::jsonb))) $$,
  '23514', null, 'a conversion needs a positive factor');
select is((select count(*)::int from public.lab_results where lab_report_id = '00000000-0000-0000-0000-00000051a301'), 3,
  'a refused filing leaves the previous results untouched');

-- Filing another report with a file the patient already has: 23505.
reset role;
select set_config('request.jwt.claims', '', true);
insert into public.lab_reports (id, org_id, patient_id, report_type, data) values
  ('00000000-0000-0000-0000-00000051a302', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'patient_upload', '{}');
select tests.authenticate_as_service_role();
select throws_ok($$ select public.lab_pipeline_file_results('00000000-0000-0000-0000-00000051a302',
    (select report from app05_payload), (select results from app05_payload)) $$,
  '23505', null, 'a legacy report whose file the patient already filed is refused as a duplicate');
select is((select count(*)::int from public.lab_results where lab_report_id = '00000000-0000-0000-0000-00000051a302'), 0,
  'nothing is filed for the duplicate');
select throws_ok($$ select public.lab_pipeline_file_results(gen_random_uuid(), '{}', '[]') $$,
  'P0002', null, 'an unknown report is refused');

-- ---------------------------------------------------------------------------
-- Who reads the filed results (unchanged TC-015 policies, new columns)
-- ---------------------------------------------------------------------------

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select is((select count(*)::int from public.lab_results where lab_report_id = '00000000-0000-0000-0000-00000051a301' and reported_unit is not null), 3,
  'the patient''s own-clinic physician reads the results, including the as-reported columns');
select tests.authenticate_as('00000000-0000-0000-0000-0000000b1001', 'aal1');
select is((select count(*)::int from public.lab_results where lab_report_id = '00000000-0000-0000-0000-00000051a301'), 0,
  'another patient sees none of them');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1');
select throws_ok($$ insert into public.lab_results (org_id, patient_id, lab_report_id, analyte_key, analyte_label) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000051a301', 'hba1c', 'HbA1c') $$,
  '42501', null, 'the patient still cannot write lab_results directly');

select * from finish();
rollback;
