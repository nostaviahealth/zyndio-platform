-- POR-04: pre-visit brief.
--
-- Proves: "since" is the last visit (else program start); out-of-range lists
-- only the latest result per marker that is outside; changes compare the first
-- and latest trend-eligible results in the same unit; flags and missing-data
-- codes; the payload is structured facts only (no free text keys); identity-
-- held results never count; the not-found contract for other clinic / unknown
-- id / org_admin; one audit row per view; record_patient_visit is physician /
-- care_coordinator only and audited.
-- Fixtures live in this transaction (UUIDs ...752...) and are rolled back.
begin;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);

insert into public.patient_roster_meta (patient_id, org_id, sex, program_started_on, open_questions)
values ('00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000000000a', 'female', current_date - 200, 2)
on conflict (patient_id) do update set program_started_on = excluded.program_started_on, open_questions = excluded.open_questions;
insert into public.lab_reports (id, org_id, patient_id, report_type, data, identity_hold) values
  ('00000000-0000-0000-0000-000000752a01', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'metabolic_panel', '{}', false),
  ('00000000-0000-0000-0000-000000752a02', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'metabolic_panel', '{}', false),
  ('00000000-0000-0000-0000-000000752a03', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'metabolic_panel', '{}', true);
insert into public.lab_results
  (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value, unit, status, range_low, range_high, taken_at) values
  -- baseline report (180 days ago)
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-000000752a01', 'hba1c', 'HbA1c', 6.4, '%', 'outside_range', null, 5.7, now() - interval '180 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-000000752a01', 'apob', 'ApoB', 95, 'mg/dL', 'no_range', null, null, now() - interval '180 days'),
  -- latest report (20 days ago): HbA1c within, glucose outside, hsCRP needs review
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-000000752a02', 'hba1c', 'HbA1c', 5.6, '%', 'within_range', null, 5.7, now() - interval '20 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-000000752a02', 'glucose_fasting', 'Glucose, fasting', 104, 'mg/dL', 'outside_range', 70, 99, now() - interval '20 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-000000752a02', 'hscrp', 'hsCRP', 1.7, 'mg/L', 'needs_review', null, null, now() - interval '20 days'),
  -- identity-held (5 days ago): must never count
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-000000752a03', 'triglycerides', 'Triglycerides', 400, 'mg/dL', 'outside_range', null, 150, now() - interval '5 days');

create temp table _b (k text primary key, v jsonb) on commit drop;
grant all on _b to authenticated;

-- ---------------------------------------------------------------------------
-- No visit yet: since = program start
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
insert into _b select 'first', public.patient_previsit_brief('00000000-0000-0000-0000-0000000a1001');
select is((select v #>> '{since,basis}' from _b where k = 'first'), 'program_start', 'no visit: since = program start');
select is((select v ->> 'treatment' from _b where k = 'first'), null, 'no treatment on record -> null treatment');
select ok((select v -> 'missing' @> '[{"code":"no_treatment"}]' from _b where k = 'first'), 'missing: no_treatment');
select is((select jsonb_array_length(v -> 'out_of_range') from _b where k = 'first'), 1,
  'out of range: only glucose (HbA1c''s latest is within; held triglycerides excluded)');
select is((select v #>> '{out_of_range,0,analyte_key}' from _b where k = 'first'), 'glucose_fasting', 'out of range: glucose');
select is((select (v #>> '{flags,needs_review}')::int from _b where k = 'first'), 1, 'flags: one marker needs review');
select is((select (v #>> '{flags,open_questions}')::int from _b where k = 'first'), 2, 'flags: open questions');
select ok((select (v #>> '{flags,identity_hold}')::boolean from _b where k = 'first'), 'flags: identity hold present');
select is((select jsonb_array_length(v -> 'changes') from _b where k = 'first'), 1, 'changes: only HbA1c has a baseline and a later result');
select is((select (v #>> '{changes,0,baseline_value}')::numeric from _b where k = 'first'), 6.4, 'changes: baseline 6.4');
select is((select (v #>> '{changes,0,latest_value}')::numeric from _b where k = 'first'), 5.6, 'changes: latest 5.6');
select is((select (v #>> '{changes,0,delta}')::numeric from _b where k = 'first'), -0.8, 'changes: delta -0.8');
select ok(not (select v::text from _b where k = 'first') ilike '%triglycerides%', 'identity-held marker appears nowhere');
select ok(not (select v::text from _b where k = 'first') ilike '%dose%', 'no dose in the brief');
-- Structured facts only: the payload's top-level keys are a fixed set.
select is((select array_agg(k2 order by k2) from _b, jsonb_object_keys(v) k2 where k = 'first'),
  array['changes','counts','flags','generated_at','last_visit_on','missing','out_of_range','patient_id','since','treatment'],
  'payload keys are the fixed template sections');

-- ---------------------------------------------------------------------------
-- Visits
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2'); -- read_only_a
select throws_ok($$ select public.record_patient_visit('00000000-0000-0000-0000-0000000a1001', current_date) $$, '42501', null,
  'read_only cannot record a visit');
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2'); -- physician_b
select throws_ok($$ select public.record_patient_visit('00000000-0000-0000-0000-0000000a1001', current_date) $$, 'P0002', null,
  'another clinic cannot record a visit');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2'); -- care_coordinator_a
select throws_ok($$ select public.record_patient_visit('00000000-0000-0000-0000-0000000a1001', current_date + 30) $$, '22023', null,
  'a visit cannot be in the future');
select lives_ok($$ select public.record_patient_visit('00000000-0000-0000-0000-0000000a1001', current_date - 10) $$,
  'care_coordinator records a visit 10 days ago');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
insert into _b select 'after_visit', public.patient_previsit_brief('00000000-0000-0000-0000-0000000a1001');
select is((select v #>> '{since,basis}' from _b where k = 'after_visit'), 'last_visit', 'since = last visit');
select is((select v ->> 'last_visit_on' from _b where k = 'after_visit'), (current_date - 10)::text, 'last visit date reported');
select is((select (v #>> '{counts,results_since}')::int from _b where k = 'after_visit'), 0, 'no results since the visit');
select ok((select v -> 'missing' @> '[{"code":"no_labs_since_visit"}]' from _b where k = 'after_visit'), 'missing: no labs since visit');
select ok((select v -> 'missing' @> '[{"code":"marker_not_rechecked","analyte_key":"apob"}]' from _b where k = 'after_visit'),
  'missing: ApoB not rechecked since the visit');
select ok((select v -> 'timeline' is null from _b where k = 'after_visit'), 'no unexpected sections');

-- ---------------------------------------------------------------------------
-- Not-found contract + audit
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2');
select is(public.patient_previsit_brief('00000000-0000-0000-0000-0000000a1001'), null, 'other clinic: null');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select is(public.patient_previsit_brief('00000000-0000-0000-0000-0000009e9e9e'), null, 'unknown id: null');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
select is(public.patient_previsit_brief('00000000-0000-0000-0000-0000000a1001'), null, 'org_admin: null');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2');
select isnt(public.patient_previsit_brief('00000000-0000-0000-0000-0000000a1001'), null, 'read_only can read the brief');

reset role;
select set_config('request.jwt.claims', '', true);
select is((select count(*)::int from public.audit_log where event_type = 'previsit_brief_viewed'
            and target_user_id = '00000000-0000-0000-0000-0000000a1001'), 3,
  'one audit row per visible brief view (2 physician + 1 read_only), none for refused views');
select is((select count(*)::int from public.audit_log where event_type = 'patient_visit_recorded'
            and actor_user_id = '00000000-0000-0000-0000-0000000a0003'), 1, 'visit recording audited');
select is((select count(*)::int from public.patient_visits where patient_id = '00000000-0000-0000-0000-0000000a1001'), 1,
  'refused visit attempts wrote nothing');

select * from finish();
rollback;
