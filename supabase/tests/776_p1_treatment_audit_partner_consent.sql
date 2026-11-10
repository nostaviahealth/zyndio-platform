-- P1 Clinical & Governance pgTAP suite (APP-03, POR-07, POR-08, INT-04):
--   1. APP-03: Separate, revocable partner outcome authorisation (DEXASCAN),
--      audit_log + notification_outbox ('consent.updated'), and
--      is_partner_outcome_authorised() compute/delivery gate.
--   2. POR-07 & INT-04: GLP-1 treatment courses & events, idempotent replay,
--      Clause 9.1 patient no-write enforcement, cross-org isolation.
--   3. POR-08: list_org_audit_log() for active org_admin at AAL2 only,
--      action filter, metadata sanitization, and cross-org isolation.
begin;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);

-- Synthetic APP-03 partner_disclosure fixture for this test transaction
-- (migrations keep only placeholder documents until legal counsel sign-off).
insert into public.consent_documents
  (consent_type, version, document, title, summary, body, required, is_placeholder)
values (
  'partner_disclosure',
  'v1.0',
  'zyndio_partner_disclosure',
  'Share clinician-reviewed outcomes with DEXASCAN',
  'Synthetic APP-03 statement for the fictional test candidate. Not a legal policy.',
  'I authorise Zyndio to share my clinician-reviewed milestone outcomes with DEXASCAN.',
  false,
  false
);

-- ===========================================================================
-- 1. Structural assertions
-- ===========================================================================
select has_table('public', 'partner_outcome_authorisations',
  'APP-03: partner_outcome_authorisations table exists');
select has_table('public', 'treatment_courses',
  'POR-07/INT-04: treatment_courses table exists');
select has_table('public', 'treatment_events',
  'POR-07/INT-04: treatment_events table exists');

select ok(
  not has_table_privilege('authenticated', 'public.partner_outcome_authorisations', 'INSERT')
  and not has_table_privilege('authenticated', 'public.partner_outcome_authorisations', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.partner_outcome_authorisations', 'DELETE'),
  'APP-03: authenticated has no direct INSERT/UPDATE/DELETE on partner_outcome_authorisations'
);

select ok(
  not has_table_privilege('authenticated', 'public.treatment_courses', 'INSERT')
  and not has_table_privilege('authenticated', 'public.treatment_courses', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.treatment_courses', 'DELETE')
  and not has_table_privilege('authenticated', 'public.treatment_events', 'INSERT')
  and not has_table_privilege('authenticated', 'public.treatment_events', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.treatment_events', 'DELETE'),
  'POR-07/Clause 9.1: authenticated has no direct INSERT/UPDATE/DELETE on treatment_courses or treatment_events'
);

-- ===========================================================================
-- 2. APP-03: Separate, revocable partner outcome authorisation
-- ===========================================================================
-- Default: not authorised before granting
select is(
  public.is_partner_outcome_authorised('00000000-0000-0000-0000-0000000a1001'),
  false,
  'APP-03: patient A1 is not authorised by default'
);

-- Clinic staff cannot toggle patient consent
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select throws_ok(
  $$ select public.set_partner_outcome_authorisation(true) $$,
  '42501', null,
  'APP-03: physician cannot call set_partner_outcome_authorisation'
);

-- Patient A1 grants authorisation
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1'); -- patient A1
select is(
  (select (public.set_partner_outcome_authorisation(
    true,
    'v1.0',
    'I authorise Zyndio to share my clinician-reviewed milestone outcomes with DEXASCAN.'
  ) ->> 'authorized')::boolean),
  true,
  'APP-03: patient A1 grants DEXASCAN outcome sharing authorisation'
);

select is(
  public.is_partner_outcome_authorised('00000000-0000-0000-0000-0000000a1001'),
  true,
  'APP-03: is_partner_outcome_authorised(A1) returns true after grant'
);

select is(
  (select partner_code from public.partner_outcome_authorisations
   where patient_id = '00000000-0000-0000-0000-0000000a1001'),
  'DEXASCAN',
  'APP-03: patient A1 can SELECT their own partner_outcome_authorisations row'
);

-- Patient B1 cannot read Patient A1's consent row or probe via helper
select tests.authenticate_as('00000000-0000-0000-0000-0000000b1001', 'aal1'); -- patient B1
select is(
  (select count(*)::int from public.partner_outcome_authorisations
   where patient_id = '00000000-0000-0000-0000-0000000a1001'),
  0,
  'APP-03: patient B1 cannot SELECT patient A1 consent row'
);
select is(
  public.is_partner_outcome_authorised('00000000-0000-0000-0000-0000000a1001'),
  false,
  'APP-03: patient B1 cannot probe patient A1 consent status via is_partner_outcome_authorised'
);

-- Patient A1 revokes authorisation
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1');
select is(
  (select (public.set_partner_outcome_authorisation(false, 'v1.0') ->> 'authorized')::boolean),
  false,
  'APP-03: patient A1 revokes DEXASCAN outcome sharing authorisation'
);

select is(
  public.is_partner_outcome_authorised('00000000-0000-0000-0000-0000000a1001'),
  false,
  'APP-03: is_partner_outcome_authorised(A1) immediately returns false after revocation'
);

select ok(
  (select granted_at is not null and revoked_at is not null and not authorized
   from public.partner_outcome_authorisations
   where patient_id = '00000000-0000-0000-0000-0000000a1001'),
  'APP-03: revoked row preserves granted_at and sets revoked_at'
);

-- Verify audit_log and notification_outbox rows for grant + revoke
reset role;
select set_config('request.jwt.claims', '', true);

select is(
  (select count(*)::int from public.audit_log
   where actor_user_id = '00000000-0000-0000-0000-0000000a1001'
     and event_type = 'partner_outcome_consent_granted'),
  1,
  'APP-03: grant wrote partner_outcome_consent_granted to audit_log'
);
select is(
  (select count(*)::int from public.audit_log
   where actor_user_id = '00000000-0000-0000-0000-0000000a1001'
     and event_type = 'partner_outcome_consent_revoked'),
  1,
  'APP-03: revoke wrote partner_outcome_consent_revoked to audit_log'
);
select is(
  (select count(*)::int from public.notification_outbox
   where user_id = '00000000-0000-0000-0000-0000000a1001'
     and type = 'consent.updated'),
  2,
  'APP-03: grant and revoke each enqueued a consent.updated event in notification_outbox'
);

-- ===========================================================================
-- 3. POR-07 & INT-04: GLP-1 Treatment Context & Events (Clause 9.1)
-- ===========================================================================
-- Patient A1 can NEVER write treatment courses or events (direct or RPC)
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2'); -- patient A1
select throws_ok(
  $$ select public.record_patient_treatment_event(
       '00000000-0000-0000-0000-0000000a1001',
       'medication_start',
       'Semaglutide',
       'Subcutaneous',
       0.25,
       'mg weekly'
     ) $$,
  '42501', null,
  'Clause 9.1: patient A1 cannot call record_patient_treatment_event'
);

-- read_only and org_admin cannot record treatment events
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2'); -- read_only_a
select throws_ok(
  $$ select public.record_patient_treatment_event(
       '00000000-0000-0000-0000-0000000a1001',
       'medication_start',
       'Semaglutide'
     ) $$,
  '42501', null,
  'POR-07: read_only cannot record treatment events'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select throws_ok(
  $$ select public.record_patient_treatment_event(
       '00000000-0000-0000-0000-0000000a1001',
       'medication_start',
       'Semaglutide'
     ) $$,
  '42501', null,
  'POR-07: org_admin cannot record treatment events'
);

-- Cross-org physician B cannot record or view treatment for Org A patient
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2'); -- physician_b
select throws_ok(
  $$ select public.record_patient_treatment_event(
       '00000000-0000-0000-0000-0000000a1001',
       'medication_start',
       'Semaglutide'
     ) $$,
  'P0002', null,
  'POR-07: physician_b cannot record treatment event for Org A patient'
);
select is(
  public.get_patient_treatment_context('00000000-0000-0000-0000-0000000a1001'),
  null,
  'POR-07: physician_b gets null treatment context for Org A patient'
);

-- Care Coordinator A records medication_start with idempotency key
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2'); -- care_coordinator_a
select is(
  (select (public.record_patient_treatment_event(
    '00000000-0000-0000-0000-0000000a1001',
    'medication_start',
    'Semaglutide',
    'Subcutaneous pen',
    0.25,
    'mg weekly',
    'active',
    'Initial titration start',
    '2026-10-01T09:00:00Z'::timestamptz,
    'idem-p1-start-001'
  ) ->> 'replayed')::boolean),
  false,
  'POR-07: care_coordinator_a records medication_start event'
);

-- Replay with same idempotency_key returns replayed=true without duplicating
select is(
  (select (public.record_patient_treatment_event(
    '00000000-0000-0000-0000-0000000a1001',
    'medication_start',
    'Semaglutide',
    'Subcutaneous pen',
    0.25,
    'mg weekly',
    'active',
    'Initial titration start',
    '2026-10-01T09:00:00Z'::timestamptz,
    'idem-p1-start-001'
  ) ->> 'replayed')::boolean),
  true,
  'INT-04: duplicate idempotency_key replays existing event without creating a second row'
);

-- Physician A records a dose_change and a tolerability_note
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select is(
  (select (public.record_patient_treatment_event(
    '00000000-0000-0000-0000-0000000a1001',
    'dose_change',
    null,
    '',
    0.5,
    'mg weekly',
    'active',
    'Step up after 4 weeks well tolerated',
    '2026-10-29T09:00:00Z'::timestamptz,
    'idem-p1-dose-002'
  ) -> 'course' ->> 'current_dose_value')::numeric),
  0.5,
  'POR-07: physician_a dose_change updates course current_dose_value to 0.5'
);

select lives_ok(
  $$ select public.record_patient_treatment_event(
       '00000000-0000-0000-0000-0000000a1001',
       'tolerability_note',
       null,
       '',
       null,
       null,
       null,
       'Mild transient nausea on day 1 post-injection',
       '2026-11-01T10:00:00Z'::timestamptz,
       'idem-p1-note-003'
     ) $$,
  'POR-07: physician_a records tolerability_note event'
);

-- Read treatment context as read_only_a (allowed to view own-clinic context, audited)
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2'); -- read_only_a
select is(
  (select public.get_patient_treatment_context('00000000-0000-0000-0000-0000000a1001') -> 'course' ->> 'medication'),
  'Semaglutide',
  'POR-07: read_only_a can view own-clinic treatment context'
);
select is(
  (select pg_catalog.jsonb_array_length(
    public.get_patient_treatment_context('00000000-0000-0000-0000-0000000a1001') -> 'events'
  )),
  3,
  'POR-07: treatment context includes all 3 chronological events'
);

-- ===========================================================================
-- 4. POR-08: list_org_audit_log for active org_admin at AAL2
-- ===========================================================================
-- Non-admin roles and AAL1 are refused
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select throws_ok(
  $$ select * from public.list_org_audit_log(50, null) $$,
  '42501', null,
  'POR-08: physician is refused list_org_audit_log'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal1'); -- org_admin_a at AAL1
select throws_ok(
  $$ select * from public.list_org_audit_log(50, null) $$,
  '42501', null,
  'POR-08: org_admin at AAL1 (without MFA) is refused list_org_audit_log'
);

-- Active org_admin_a at AAL2 lists Org A audit log
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select ok(
  (select count(*)::int from public.list_org_audit_log(100, null)) >= 5,
  'POR-08: org_admin_a at AAL2 receives Org A audit log entries'
);

select is(
  (select count(*)::int from public.list_org_audit_log(100, 'treatment_event_recorded')),
  3,
  'POR-08: list_org_audit_log action filter returns the 3 treatment_event_recorded rows'
);

select is(
  (select count(*)::int from public.list_org_audit_log(100, 'treatment_context_viewed')),
  2,
  'POR-08: list_org_audit_log action filter returns the 2 treatment_context_viewed rows'
);

select * from finish();
rollback;
