-- Phase 2 (C2) pgTAP suite: Outcomes Engine, DEXASCAN Body Composition Scans,
-- Outcomes Review Queue (POR-09), Unmatched Partner Scans Queue (POR-10),
-- and Immutability of Delivered Outcome Records.
begin;
set local search_path = public, extensions, pg_catalog;
select no_plan();

-- ---------------------------------------------------------------------------
-- 1. Schema presence & privilege checks
-- ---------------------------------------------------------------------------
select has_table('public', 'body_composition_scans', 'body_composition_scans table exists');
select has_table('public', 'outcome_records', 'outcome_records table exists');

select ok(
  not has_table_privilege('authenticated', 'public.body_composition_scans', 'INSERT')
  and not has_table_privilege('authenticated', 'public.body_composition_scans', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.body_composition_scans', 'DELETE'),
  'authenticated has no direct INSERT/UPDATE/DELETE on body_composition_scans'
);

select ok(
  not has_table_privilege('authenticated', 'public.outcome_records', 'INSERT')
  and not has_table_privilege('authenticated', 'public.outcome_records', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.outcome_records', 'DELETE'),
  'authenticated has no direct INSERT/UPDATE/DELETE on outcome_records'
);

select ok(
  not has_function_privilege('authenticated', 'public.enforce_delivered_outcome_immutability()', 'EXECUTE')
  and not has_function_privilege('anon', 'public.enforce_delivered_outcome_immutability()', 'EXECUTE'),
  'trigger function enforce_delivered_outcome_immutability() is not callable by anon/authenticated'
);

-- ---------------------------------------------------------------------------
-- 2. Seed DEXA scans (bound & unmatched) and Outcome Records in Org A & Org B
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', '', true);

insert into public.body_composition_scans (
  id, org_id, patient_id, zyndio_patient_id, partner_patient_id,
  partner_scan_id, partner_scan_version, scan_date, site_id,
  device_vendor, device_model, software_version, measures, binding_status
) values
  (
    '00000000-0000-0000-0000-000000c20001',
    '00000000-0000-0000-0000-00000000000a',
    '00000000-0000-0000-0000-0000000a1001',
    'ZP-A1001',
    'DEX-PAT-A1',
    'DEX-SCAN-A1-BASE',
    1,
    date '2026-05-01',
    'SITE-SF-01',
    'Hologic',
    'Horizon A',
    'APEX 5.6.1',
    '{"weight_lb":228,"fat_mass_lb":82,"lean_mass_lb":137,"visceral_fat":3.4}'::jsonb,
    'bound'
  ),
  (
    '00000000-0000-0000-0000-000000c20002',
    '00000000-0000-0000-0000-00000000000a',
    null,
    'ZP-UNKNOWN-999',
    'DEX-PAT-UNMATCHED-A',
    'DEX-SCAN-UNMATCHED-1',
    1,
    date '2026-10-28',
    'SITE-SF-01',
    'Hologic',
    'Horizon A',
    'APEX 5.6.1',
    '{"weight_lb":194,"fat_mass_lb":55,"lean_mass_lb":133,"visceral_fat":2.1}'::jsonb,
    'unmatched'
  ),
  (
    '00000000-0000-0000-0000-000000c20003',
    '00000000-0000-0000-0000-00000000000b',
    null,
    'ZP-UNKNOWN-B',
    'DEX-PAT-UNMATCHED-B',
    'DEX-SCAN-UNMATCHED-B1',
    1,
    date '2026-10-28',
    'SITE-NY-01',
    'GE Healthcare',
    'Lunar iDXA',
    'enCORE 18',
    '{"weight_lb":210,"fat_mass_lb":70,"lean_mass_lb":131}'::jsonb,
    'unmatched'
  );

-- Unique constraint on (org_id, partner_scan_id, partner_scan_version)
select throws_ok(
  $$
  insert into public.body_composition_scans (
    org_id, partner_patient_id, partner_scan_id, partner_scan_version,
    scan_date, device_vendor, device_model, software_version, measures, binding_status
  ) values (
    '00000000-0000-0000-0000-00000000000a', 'DEX-PAT-A1', 'DEX-SCAN-A1-BASE', 1,
    date '2026-05-01', 'Hologic', 'Horizon A', 'APEX 5.6.1', '{}'::jsonb, 'bound'
  )
  $$,
  '23505',
  null,
  'duplicate (org_id, partner_scan_id, partner_scan_version) is rejected'
);

insert into public.outcome_records (
  id, record_id, org_id, patient_id, milestone, record_version, rules_version,
  state, lean_mass_flag, clinical_context_flag, clinician_summary, payload
) values
  (
    '00000000-0000-0000-0000-000000c21001',
    'rec_a1_d180_v1',
    '00000000-0000-0000-0000-00000000000a',
    '00000000-0000-0000-0000-0000000a1001',
    'd180',
    1,
    'v1.0',
    'in_review',
    'flagged',
    true,
    '[Milestone D180] Total weight 228 -> 194 lb (-34 lb, -14.9%, improving). Clinical context flag: RAISED.',
    '{"record_id":"rec_a1_d180_v1","partner_patient_id":"DEX-PAT-A1","zyndio_patient_token":"zpt_fixture_a1"}'::jsonb
  ),
  (
    '00000000-0000-0000-0000-000000c21002',
    'rec_b1_d90_v1',
    '00000000-0000-0000-0000-00000000000b',
    '00000000-0000-0000-0000-0000000b1001',
    'd90',
    1,
    'v1.0',
    'in_review',
    'none',
    false,
    '[Milestone D90] Org B record.',
    '{"record_id":"rec_b1_d90_v1"}'::jsonb
  );

-- ---------------------------------------------------------------------------
-- 3. Patient RLS on body_composition_scans (APP-13)
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1'); -- patient A1
select is(
  (select count(*)::int from public.body_composition_scans),
  1,
  'patient A1 sees only their own bound DEXA scan (unmatched and Org B scans hidden)'
);
select is(
  (select count(*)::int from public.outcome_records),
  0,
  'patient A1 cannot read staff outcome_records table directly'
);

-- ---------------------------------------------------------------------------
-- 4. POR-09: list_outcomes_review_queue & review_outcome_record
-- ---------------------------------------------------------------------------

-- org_admin is denied clinical outcomes review queue
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select throws_ok(
  $$ select * from public.list_outcomes_review_queue() $$,
  '42501',
  null,
  'org_admin cannot call list_outcomes_review_queue()'
);

-- physician at aal1 is denied
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal1'); -- physician_a aal1
select throws_ok(
  $$ select * from public.list_outcomes_review_queue() $$,
  '42501',
  null,
  'physician at aal1 cannot call list_outcomes_review_queue()'
);

-- read_only and care_coordinator at aal2 can view list_outcomes_review_queue() for their own org, but cannot call review_outcome_record()
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2'); -- read_only_a
select is(
  (select count(*)::int from public.list_outcomes_review_queue()),
  1,
  'read_only_a sees Org A outcome record in list_outcomes_review_queue()'
);
select throws_ok(
  $$ select public.review_outcome_record('rec_a1_d180_v1', 'approve', null, true, 'attempt by read_only') $$,
  '42501',
  null,
  'read_only_a cannot call review_outcome_record()'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2'); -- care_coordinator_a
select is(
  (select count(*)::int from public.list_outcomes_review_queue()),
  1,
  'care_coordinator_a sees Org A outcome record in list_outcomes_review_queue()'
);
select throws_ok(
  $$ select public.review_outcome_record('rec_a1_d180_v1', 'approve', null, true, 'attempt by coordinator') $$,
  '42501',
  null,
  'care_coordinator_a cannot call review_outcome_record() (physician-only)'
);

-- physician_a at aal2: cannot approve a flagged record without clearing clinical_context_flag!
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select throws_ok(
  $$ select public.review_outcome_record('rec_a1_d180_v1', 'approve', null, false, null) $$,
  'P0001',
  'clinical context flag must be cleared by a physician before approving an outcome record',
  'physician_a cannot approve a record while clinical_context_flag is active and not cleared'
);

-- physician_a cannot review Org B record
select throws_ok(
  $$ select public.review_outcome_record('rec_b1_d90_v1', 'approve', null, true, 'cross-org') $$,
  'P0002',
  null,
  'physician_a cannot review an Org B outcome record'
);

-- physician_a can place record on hold or send_back even while flagged
select is(
  (select public.review_outcome_record('rec_a1_d180_v1', 'hold', null, false, 'Awaiting repeat DEXA review') ->> 'state'),
  'held',
  'physician_a can place an outcome record on hold'
);

-- Verify partner disclosure consent gate: temporarily revoke consent for patient A1
reset role;
select set_config('request.jwt.claims', '', true);
update public.consents set granted = false where patient_id = '00000000-0000-0000-0000-0000000a1001';

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select throws_ok(
  $$ select public.review_outcome_record('rec_a1_d180_v1', 'approve', 'Reviewed summary.', true, 'Flag cleared') $$,
  'P0001',
  'partner disclosure consent is required before approving an outcome record',
  'physician_a cannot approve an outcome record when partner disclosure consent is not granted'
);

-- Restore consent and approve with clinical flag cleared
reset role;
select set_config('request.jwt.claims', '', true);
update public.consents set granted = true where patient_id = '00000000-0000-0000-0000-0000000a1001';

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select is(
  (select public.review_outcome_record(
    'rec_a1_d180_v1',
    'approve',
    '[Milestone D180] Physician-approved summary: weight -34 lb (-14.9%), lean mass counselled.',
    true,
    'Reviewed resistance training and protein protocol with patient.'
  ) ->> 'state'),
  'approved',
  'physician_a approves the outcome record after clearing clinical_context_flag with consent present'
);

reset role;
select set_config('request.jwt.claims', '', true);
select is(
  (select clinical_context_flag from public.outcome_records where record_id = 'rec_a1_d180_v1'),
  false,
  'clinical_context_flag is false after physician clearance'
);
select is(
  (select clinical_flag_cleared_by from public.outcome_records where record_id = 'rec_a1_d180_v1'),
  '00000000-0000-0000-0000-0000000a0002'::uuid,
  'clinical_flag_cleared_by records the physician UUID'
);
select is(
  (select count(*)::int from public.audit_log where event_type = 'outcome_record_reviewed' and metadata ->> 'record_id' = 'rec_a1_d180_v1' and metadata ->> 'decision' = 'approved'),
  1,
  'audit_log records outcome_record_reviewed approval event'
);

-- ---------------------------------------------------------------------------
-- 5. Immutability of delivered outcome records (corrections must use version + 1)
-- ---------------------------------------------------------------------------
update public.outcome_records set state = 'delivered' where record_id = 'rec_a1_d180_v1';

select throws_ok(
  $$ update public.outcome_records set clinician_summary = 'Mutated in place!' where record_id = 'rec_a1_d180_v1' $$,
  'P0001',
  'delivered outcome records are immutable; insert record_version + 1 to issue a correction',
  'delivered outcome record cannot have clinician_summary mutated in place'
);

select throws_ok(
  $$ update public.outcome_records set payload = '{"tampered":true}'::jsonb where record_id = 'rec_a1_d180_v1' $$,
  'P0001',
  'delivered outcome records are immutable; insert record_version + 1 to issue a correction',
  'delivered outcome record cannot have payload mutated in place'
);

-- Issuing a correction via record_version + 1 succeeds
insert into public.outcome_records (
  record_id, org_id, patient_id, milestone, record_version, rules_version,
  state, lean_mass_flag, clinical_context_flag, clinician_summary, payload
) values (
  'rec_a1_d180_v2',
  '00000000-0000-0000-0000-00000000000a',
  '00000000-0000-0000-0000-0000000a1001',
  'd180',
  2,
  'v1.0',
  'in_review',
  'watch',
  false,
  '[Milestone D180 v2] Corrected follow-up record.',
  '{"record_id":"rec_a1_d180_v2","record_version":2}'::jsonb
);
select is(
  (select record_version from public.outcome_records where record_id = 'rec_a1_d180_v2'),
  2,
  'correction inserted as record_version = 2 while v1 remains immutable'
);

-- ---------------------------------------------------------------------------
-- 6. POR-10: list_unmatched_partner_scans & bind_unmatched_partner_scan
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2'); -- read_only_a
select throws_ok(
  $$ select * from public.list_unmatched_partner_scans() $$,
  '42501',
  null,
  'read_only_a cannot call list_unmatched_partner_scans()'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2'); -- care_coordinator_a
select is(
  (select count(*)::int from public.list_unmatched_partner_scans()),
  1,
  'care_coordinator_a sees the 1 unmatched scan in Org A (Org B unmatched scan excluded)'
);

-- Cannot bind Org A scan to Org B patient
select throws_ok(
  $$ select public.bind_unmatched_partner_scan('00000000-0000-0000-0000-000000c20002', '00000000-0000-0000-0000-0000000b1001') $$,
  'P0002',
  null,
  'care_coordinator_a cannot bind an Org A scan to an Org B patient'
);

-- Cannot bind Org B scan
select throws_ok(
  $$ select public.bind_unmatched_partner_scan('00000000-0000-0000-0000-000000c20003', '00000000-0000-0000-0000-0000000a1001') $$,
  'P0002',
  null,
  'care_coordinator_a cannot bind an Org B scan'
);

-- Valid bind in Org A succeeds
select is(
  (select public.bind_unmatched_partner_scan('00000000-0000-0000-0000-000000c20002', '00000000-0000-0000-0000-0000000a1001') ->> 'binding_status'),
  'bound',
  'care_coordinator_a binds unmatched scan to patient A1'
);

select is(
  (select count(*)::int from public.list_unmatched_partner_scans()),
  0,
  'unmatched queue in Org A is now empty after binding'
);

-- Re-binding an already bound scan fails
select throws_ok(
  $$ select public.bind_unmatched_partner_scan('00000000-0000-0000-0000-000000c20002', '00000000-0000-0000-0000-0000000a1001') $$,
  'P0001',
  'scan is already bound or rejected',
  'cannot re-bind a scan that is already bound'
);

reset role;
select set_config('request.jwt.claims', '', true);
select is(
  (select count(*)::int from public.audit_log where event_type = 'partner_scan_bound' and target_user_id = '00000000-0000-0000-0000-0000000a1001'),
  1,
  'audit_log records partner_scan_bound event'
);

select * from finish();
rollback;
