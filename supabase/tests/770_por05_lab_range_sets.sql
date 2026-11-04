-- POR-05: versioned, physician-approved reference-range sets.
--
-- Proves: physician-only drafting and approval (care_coordinator, read_only,
-- org_admin, aal1 and another clinic are refused), no direct client writes,
-- one draft / one live set per clinic, approved sets frozen even for the
-- service role, every change audited, and that biomarker flags (latest
-- results, trend, roster rollup) switch to the approved set - matching unit
-- and the patient's sex only - while range_source tells the portal when the
-- default-range caveat still applies.
-- Fixtures live in this transaction (UUIDs ...750...) and are rolled back.
begin;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);

-- Patient A1 is female; one HbA1c (5.6 %, default high 5.7 -> within) and one
-- fasting glucose (104 mg/dL, default 70-99 -> outside).
insert into public.patient_roster_meta (patient_id, org_id, sex, birth_date, program_started_on)
values ('00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000000000a', 'female', '1985-03-01', current_date - 120)
on conflict (patient_id) do update set sex = excluded.sex;
insert into public.lab_reports (id, org_id, patient_id, report_type, data, identity_hold) values
  ('00000000-0000-0000-0000-000000750a01', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'metabolic_panel', '{}', false);
insert into public.lab_results
  (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value, unit, status, range_low, range_high, taken_at) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-000000750a01', 'hba1c', 'HbA1c', 5.6, '%', 'within_range', null, 5.7, now() - interval '10 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-000000750a01', 'glucose_fasting', 'Glucose, fasting', 104, 'mg/dL', 'outside_range', 70, 99, now() - interval '10 days');

-- ---------------------------------------------------------------------------
-- Structure
-- ---------------------------------------------------------------------------
select has_table('public', 'lab_range_sets', 'lab_range_sets exists');
select has_table('public', 'lab_range_set_items', 'lab_range_set_items exists');
select ok((select relforcerowsecurity from pg_class where oid = 'public.lab_range_sets'::regclass), 'lab_range_sets has FORCE RLS');
select ok((select relforcerowsecurity from pg_class where oid = 'public.lab_range_set_items'::regclass), 'lab_range_set_items has FORCE RLS');
select ok(not has_table_privilege('authenticated', 'public.lab_range_set_items', 'INSERT'), 'authenticated has no INSERT on lab_range_set_items');
select ok(not has_table_privilege('authenticated', 'public.lab_range_sets', 'UPDATE'), 'authenticated has no UPDATE on lab_range_sets');

-- ---------------------------------------------------------------------------
-- Before any approved set: default ranges, caveat applies
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select is((select range_source from public.patient_latest_results('00000000-0000-0000-0000-0000000a1001') where analyte_key = 'hba1c'),
  'default', 'no approved set: HbA1c range_source is default');
select is((select status from public.patient_latest_results('00000000-0000-0000-0000-0000000a1001') where analyte_key = 'hba1c'),
  'within_range', 'no approved set: HbA1c keeps its stored status');

-- ---------------------------------------------------------------------------
-- Who may draft
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2'); -- read_only_a
select throws_ok($$ select public.create_range_set_draft(null) $$, '42501', null, 'read_only cannot create a draft');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2'); -- care_coordinator_a
select throws_ok($$ select public.create_range_set_draft(null) $$, '42501', null, 'care_coordinator cannot create a draft');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select throws_ok($$ select public.create_range_set_draft(null) $$, '42501', null, 'org_admin cannot create a draft');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal1'); -- physician_a at aal1
select throws_ok($$ select public.create_range_set_draft(null) $$, '42501', null, 'physician at aal1 cannot create a draft');
select tests.authenticate_as_anon();
select throws_ok($$ select public.create_range_set_draft(null) $$, '42501', null, 'anon cannot call create_range_set_draft');

-- ---------------------------------------------------------------------------
-- Draft v1
-- ---------------------------------------------------------------------------
reset role;
create temp table _v (k text primary key, id uuid) on commit drop;
grant all on _v to authenticated, service_role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
insert into _v select 'v1', public.create_range_set_draft('Initial clinic ranges');
select throws_ok($$ select public.create_range_set_draft(null) $$, 'P0001', null, 'a second draft is refused while one exists');
select lives_ok($$ select public.upsert_range_set_item((select id from _v where k = 'v1'), 'hba1c', 'HbA1c', 'female', null, 5.5, '%') $$,
  'physician saves an HbA1c female row');
select lives_ok($$ select public.upsert_range_set_item((select id from _v where k = 'v1'), 'glucose_fasting', 'Glucose, fasting', 'any', 3.9, 5.5, 'mmol/L') $$,
  'physician saves a glucose row in a different unit (mmol/L)');
select lives_ok($$ select public.upsert_range_set_item((select id from _v where k = 'v1'), 'apob', 'ApoB', 'male', null, 90, 'mg/dL') $$,
  'physician saves a male-only ApoB row');
select throws_ok($$ select public.upsert_range_set_item((select id from _v where k = 'v1'), 'hba1c', 'HbA1c', 'female', 6, 5, '%') $$,
  '23514', null, 'low >= high is refused by the table check');
select throws_ok($$ select public.upsert_range_set_item((select id from _v where k = 'v1'), 'hba1c', 'HbA1c', 'female', null, null, '%') $$,
  '23514', null, 'a row with neither low nor high is refused');
select throws_ok($$ insert into public.lab_range_set_items (range_set_id, org_id, analyte_key, analyte_label, sex, high, unit)
                    values ((select id from _v where k = 'v1'), '00000000-0000-0000-0000-00000000000a', 'ldl', 'LDL', 'any', 100, 'mg/dL') $$,
  '42501', null, 'a direct client INSERT into lab_range_set_items is refused');

-- Draft is not live yet.
select is((select range_source from public.patient_latest_results('00000000-0000-0000-0000-0000000a1001') where analyte_key = 'hba1c'),
  'default', 'a draft does not change flags');

-- Other clinic cannot see or act on it.
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2'); -- physician_b
select throws_ok($$ select * from public.get_range_set_items((select id from _v where k = 'v1')) $$, 'P0002', null,
  'physician_b: another clinic''s set is not found');
select throws_ok($$ select public.approve_range_set((select id from _v where k = 'v1')) $$, 'P0002', null,
  'physician_b cannot approve another clinic''s draft');
select is((select count(*)::int from public.list_range_sets()), 0, 'physician_b lists no sets of clinic A');
select is((select count(*)::int from public.lab_range_sets), 0, 'physician_b: RLS hides clinic A sets');

-- read_only may read, not act.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2'); -- read_only_a
select is((select count(*)::int from public.list_range_sets()), 1, 'read_only sees the clinic''s draft in the list');
select throws_ok($$ select public.approve_range_set((select id from _v where k = 'v1')) $$, '42501', null, 'read_only cannot approve');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2'); -- care_coordinator_a
select throws_ok($$ select public.approve_range_set((select id from _v where k = 'v1')) $$, '42501', null, 'care_coordinator cannot approve');

-- ---------------------------------------------------------------------------
-- Approve v1
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select lives_ok($$ select public.approve_range_set((select id from _v where k = 'v1')) $$, 'physician approves v1');
select is((select status from public.lab_range_sets where id = (select id from _v where k = 'v1')), 'approved', 'v1 is live');

select is((select range_source from public.patient_latest_results('00000000-0000-0000-0000-0000000a1001') where analyte_key = 'hba1c'),
  'approved', 'approved set: HbA1c range_source is approved (caveat off)');
select is((select range_set_version from public.patient_latest_results('00000000-0000-0000-0000-0000000a1001') where analyte_key = 'hba1c'),
  1, 'approved set: version 1 reported');
select is((select range_high from public.patient_latest_results('00000000-0000-0000-0000-0000000a1001') where analyte_key = 'hba1c'),
  5.5::numeric, 'approved set: HbA1c high comes from the approved row');
select is((select status from public.patient_latest_results('00000000-0000-0000-0000-0000000a1001') where analyte_key = 'hba1c'),
  'outside_range', 'approved set: 5.6 % is now flagged outside 5.5');
select is((select status from public.patient_trend('00000000-0000-0000-0000-0000000a1001', 'hba1c', 'ALL') limit 1),
  'outside_range', 'trend points use the approved set too');
select is((select range_source from public.patient_latest_results('00000000-0000-0000-0000-0000000a1001') where analyte_key = 'glucose_fasting'),
  'default', 'unit mismatch (mmol/L row vs mg/dL result): default range kept');
select is((select status from public.patient_latest_results('00000000-0000-0000-0000-0000000a1001') where analyte_key = 'glucose_fasting'),
  'outside_range', 'unit mismatch: stored status kept');

reset role;
select set_config('request.jwt.claims', '', true);
select ok((select has_outside_range from public.patient_roster_summary where patient_id = '00000000-0000-0000-0000-0000000a1001'),
  'approval refreshed the roster rollup (outside range)');
select is((select count(*)::int from public.audit_log where event_type = 'range_set_draft_created'
            and actor_user_id = '00000000-0000-0000-0000-0000000a0002' and org_id = '00000000-0000-0000-0000-00000000000a'),
  1, 'draft creation audited once');
select is((select count(*)::int from public.audit_log where event_type = 'range_set_item_saved'
            and org_id = '00000000-0000-0000-0000-00000000000a'),
  3, 'each saved row audited (refused saves write nothing)');
select is((select (metadata ->> 'version')::int from public.audit_log where event_type = 'range_set_approved'
            and org_id = '00000000-0000-0000-0000-00000000000a'),
  1, 'approval audited with the version');

-- Frozen: not via RPC, not via a direct service-role write.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select throws_ok($$ select public.upsert_range_set_item((select id from _v where k = 'v1'), 'hba1c', 'HbA1c', 'female', null, 9, '%') $$,
  'P0001', null, 'an approved set cannot be edited via the RPC');
reset role;
select tests.authenticate_as_service_role();
select throws_ok($$ update public.lab_range_set_items set high = 9 where range_set_id = (select id from _v where k = 'v1') $$,
  '42501', null, 'an approved set cannot be edited even by the service role');
select throws_ok($$ update public.lab_range_sets set status = 'draft' where id = (select id from _v where k = 'v1') $$,
  '42501', null, 'an approved set cannot go back to draft');
select throws_ok($$ delete from public.lab_range_sets where id = (select id from _v where k = 'v1') $$,
  '42501', null, 'range sets are never deleted');
reset role;

-- ---------------------------------------------------------------------------
-- v2 copies v1, approval supersedes v1
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
insert into _v select 'v2', public.create_range_set_draft(null);
select is((select count(*)::int from public.get_range_set_items((select id from _v where k = 'v2'))), 3, 'v2 starts as a copy of the live set');
select lives_ok($$ select public.upsert_range_set_item((select id from _v where k = 'v2'), 'hba1c', 'HbA1c', 'female', null, 5.7, '%') $$,
  'physician edits HbA1c in v2');
select lives_ok($$ select public.delete_range_set_item((select i.id from public.get_range_set_items((select id from _v where k = 'v2')) i where i.analyte_key = 'apob')) $$,
  'physician deletes a row in v2');
select is((select range_high from public.patient_latest_results('00000000-0000-0000-0000-0000000a1001') where analyte_key = 'hba1c'),
  5.5::numeric, 'v1 stays live while v2 is a draft');
select lives_ok($$ select public.approve_range_set((select id from _v where k = 'v2')) $$, 'physician approves v2');
select is((select status from public.lab_range_sets where id = (select id from _v where k = 'v1')), 'superseded', 'v1 superseded');
select is((select count(*)::int from public.lab_range_sets where status = 'approved'), 1, 'exactly one live set');
select is((select status from public.patient_latest_results('00000000-0000-0000-0000-0000000a1001') where analyte_key = 'hba1c'),
  'within_range', 'v2 (high 5.7): 5.6 % is within again');
select is((select range_set_version from public.patient_latest_results('00000000-0000-0000-0000-0000000a1001') where analyte_key = 'hba1c'),
  2, 'version 2 reported');

-- sex: a male-only row never applies to a female patient
reset role;
select set_config('request.jwt.claims', '', true);
insert into public.lab_results
  (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value, unit, status, taken_at) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-000000750a01', 'apob', 'ApoB', 120, 'mg/dL', 'no_range', now() - interval '5 days');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
insert into _v select 'v3', public.create_range_set_draft(null);
select lives_ok($$ select public.upsert_range_set_item((select id from _v where k = 'v3'), 'apob', 'ApoB', 'male', null, 90, 'mg/dL') $$,
  'physician adds a male-only ApoB row to v3');
select lives_ok($$ select public.approve_range_set((select id from _v where k = 'v3')) $$, 'physician approves v3');
select is((select range_source from public.patient_latest_results('00000000-0000-0000-0000-0000000a1001') where analyte_key = 'apob'),
  'none', 'male-only row does not apply to a female patient');

-- empty draft cannot be approved; a draft can be discarded (audited)
insert into _v select 'v4', public.create_range_set_draft(null);
select lives_ok($$ select public.delete_range_set_item(i.id) from public.get_range_set_items((select id from _v where k = 'v4')) i $$,
  'physician empties v4');
select throws_ok($$ select public.approve_range_set((select id from _v where k = 'v4')) $$, 'P0001', null, 'an empty set cannot be approved');
select lives_ok($$ select public.discard_range_set_draft((select id from _v where k = 'v4')) $$, 'physician discards v4');
reset role;
select set_config('request.jwt.claims', '', true);
select is((select status from public.lab_range_sets where id = (select id from _v where k = 'v4')), 'discarded', 'v4 discarded');
select is((select count(*)::int from public.audit_log where event_type = 'range_set_discarded' and org_id = '00000000-0000-0000-0000-00000000000a'),
  1, 'discard audited');
select ok((select count(*) from public.audit_log where event_type = 'range_set_item_deleted' and org_id = '00000000-0000-0000-0000-00000000000a') >= 2,
  'row deletions audited');

select * from finish();
rollback;
