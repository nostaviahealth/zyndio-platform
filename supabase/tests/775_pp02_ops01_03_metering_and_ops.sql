-- P1 Operations, Metering, and Compliance pgTAP suite (PP-02, OPS-01..03):
--   1. PP-02: Active Patients monthly metering (sign_in vs data_processed
--      deduplication per org+month+patient) and Schedule B tiered overage
--      pricing bands (1-1,000 included; 1,001-2,500 @ $0.50;
--      2,501-10,000 @ $0.35; 10,001+ @ $0.25).
--   2. OPS-01: Clause 6.6 patient data export within 30 days of termination
--      request, 60-day read-only window, deterministic JSONB manifest +
--      SHA-256 hash, and audit log entry.
--   3. OPS-02: Patient legal hold enforcement (blocks deletion with
--      patient_under_legal_hold) and written deletion confirmation certificate
--      (DEL-... code, SHA-256 certificate hash, opaque patient_ref, PII scrub).
--   4. OPS-03: Clause 8.8 72-hour security incident notification workflow
--      (notify_deadline_at = confirmed_at + 72h, notification_outbox queueing,
--      within_72h_sla verification, audit log entry).
--   5. Cross-org RLS isolation, AAL2 enforcement, and role-gating.
begin;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);

-- Seed second patient in Org A (a6002 exists in auth.users from 000_fixtures.sql)
insert into public.patients (id, org_id, display_name, mrn) values
  ('00000000-0000-0000-0000-0000000a6002', '00000000-0000-0000-0000-00000000000a', 'Fictional Patient A2', 'MRN-A2-775');
insert into public.patient_profiles (id, org_id, patient_id, data) values
  ('00000000-0000-0000-0000-00000077a202', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a6002', '{"note":"fictional-a2"}'::jsonb);
insert into public.lab_reports (id, org_id, patient_id, report_type, data) values
  ('00000000-0000-0000-0000-00000077a302', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a6002', 'lipid_panel', '{"ldl":95}'::jsonb);
insert into public.consents (id, org_id, patient_id, consent_type, granted) values
  ('00000000-0000-0000-0000-00000077a402', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a6002', 'hipaa_release', true);

-- ===========================================================================
-- 1. PP-02: Active Patients Metering & Schedule B Overage Calculation
-- ===========================================================================

-- Constraint check: usage_months.month must be the first day of a calendar month
select throws_ok(
  $$ insert into public.usage_months (org_id, month, patient_id, qualifying_reason)
     values ('00000000-0000-0000-0000-00000000000a', '2026-11-15'::date, '00000000-0000-0000-0000-0000000a1001', 'sign_in') $$,
  '23514', null,
  'PP-02: usage_months rejects a month date that is not the first day of the calendar month'
);

-- Patient A1 records sign_in activity in Nov 2026
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1');
select is(
  (public.record_patient_monthly_activity(
    '00000000-0000-0000-0000-0000000a1001',
    'sign_in',
    '2026-11-05T10:15:00Z'::timestamptz
  ) ->> 'qualifying_reason'),
  'sign_in',
  'PP-02: patient A1 records sign_in activity for 2026-11'
);

-- Subsequent data_processed activity in the same month preserves the first qualifying_reason ('sign_in')
select is(
  (public.record_patient_monthly_activity(
    '00000000-0000-0000-0000-0000000a1001',
    'data_processed',
    '2026-11-12T14:00:00Z'::timestamptz
  ) ->> 'qualifying_reason'),
  'sign_in',
  'PP-02: duplicate activity in the same month is idempotent and preserves first qualifying_reason'
);

-- Patient A1 cannot record activity for another patient (A2)
select throws_ok(
  $$ select public.record_patient_monthly_activity(
       '00000000-0000-0000-0000-0000000a6002',
       'sign_in',
       '2026-11-05T10:15:00Z'::timestamptz
     ) $$,
  '42501', null,
  'PP-02: patient A1 cannot record activity on behalf of patient A2'
);
reset role;

-- Staff (physician A at aal2) records data_processed activity for Patient A2 in Nov 2026
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select is(
  (public.record_patient_monthly_activity(
    '00000000-0000-0000-0000-0000000a6002',
    'data_processed',
    '2026-11-06T09:30:00Z'::timestamptz
  ) ->> 'qualifying_reason'),
  'data_processed',
  'PP-02: clinic staff records data_processed activity for own-org patient A2'
);
reset role;

-- Org Admin A queries monthly usage summary for Nov 2026
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
select is(
  (public.get_org_monthly_usage_summary('2026-11-01'::date) ->> 'active_patients_total')::int,
  2,
  'PP-02: get_org_monthly_usage_summary counts 2 distinct active patients in 2026-11'
);
select is(
  (public.get_org_monthly_usage_summary('2026-11-01'::date) ->> 'sign_in_count')::int,
  1,
  'PP-02: get_org_monthly_usage_summary reports 1 sign_in patient'
);
select is(
  (public.get_org_monthly_usage_summary('2026-11-01'::date) ->> 'data_processed_count')::int,
  1,
  'PP-02: get_org_monthly_usage_summary reports 1 data_processed patient'
);
select is(
  (public.get_org_monthly_usage_summary('2026-11-01'::date) ->> 'included_patients')::int,
  1000,
  'PP-02: base subscription includes 1,000 active patients'
);
select is(
  (public.get_org_monthly_usage_summary('2026-11-01'::date) ->> 'overage_fee_cents')::int,
  0,
  'PP-02: 2 active patients incur 0 cents overage fee'
);
reset role;

-- Verify Schedule B tiered overage bands (1,001-2,500 @ $0.50; 2,501-10,000 @ $0.35; 10,001+ @ $0.25)
alter table public.usage_months drop constraint usage_months_patient_id_fkey;

-- Band 1 test (2026-08-01): 1,200 active patients -> 200 overage * 50c = 10,000 cents ($100.00)
insert into public.usage_months (org_id, month, patient_id, qualifying_reason)
select
  '00000000-0000-0000-0000-00000000000a'::uuid,
  '2026-08-01'::date,
  extensions.gen_random_uuid(),
  case when g % 2 = 0 then 'sign_in' else 'data_processed' end
from generate_series(1, 1200) as g;

-- Band 2 test (2026-09-01): 3,000 active patients -> 1,500 * 50c + 500 * 35c = 75,000 + 17,500 = 92,500 cents ($925.00)
insert into public.usage_months (org_id, month, patient_id, qualifying_reason)
select
  '00000000-0000-0000-0000-00000000000a'::uuid,
  '2026-09-01'::date,
  extensions.gen_random_uuid(),
  'sign_in'
from generate_series(1, 3000) as g;

-- Band 3 test (2026-10-01): 11,000 active patients -> 1,500 * 50c + 7,500 * 35c + 1,000 * 25c = 362,500 cents ($3,625.00)
insert into public.usage_months (org_id, month, patient_id, qualifying_reason)
select
  '00000000-0000-0000-0000-00000000000a'::uuid,
  '2026-10-01'::date,
  extensions.gen_random_uuid(),
  'data_processed'
from generate_series(1, 11000) as g;

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
select is(
  (public.get_org_monthly_usage_summary('2026-08-01'::date) ->> 'billable_overage_patients')::int,
  200,
  'PP-02 Schedule B Band 1: 1,200 active patients -> 200 billable overage patients'
);
select is(
  (public.get_org_monthly_usage_summary('2026-08-01'::date) ->> 'overage_fee_cents')::int,
  10000,
  'PP-02 Schedule B Band 1: 1,200 active patients -> 10,000 cents ($100.00 at $0.50/patient)'
);
select is(
  (public.get_org_monthly_usage_summary('2026-09-01'::date) ->> 'overage_fee_cents')::int,
  92500,
  'PP-02 Schedule B Band 2: 3,000 active patients -> 92,500 cents ($925.00 across $0.50 and $0.35 tiers)'
);
select is(
  (public.get_org_monthly_usage_summary('2026-10-01'::date) ->> 'overage_fee_cents')::int,
  362500,
  'PP-02 Schedule B Band 3: 11,000 active patients -> 362,500 cents ($3,625.00 across $0.50, $0.35, and $0.25 tiers)'
);
reset role;

delete from public.usage_months where month in ('2026-08-01'::date, '2026-09-01'::date, '2026-10-01'::date);
alter table public.usage_months
  add constraint usage_months_patient_id_fkey
  foreign key (patient_id) references public.patients (id) on delete cascade;

-- ===========================================================================
-- 2. OPS-01: Patient Data Export Within 30 Days of Termination Request (6.6)
-- ===========================================================================

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');

create temp table ops01_export_result as
  select public.request_org_termination_export() as export_row;

select is(
  (select export_row ->> 'status' from ops01_export_result),
  'completed',
  'OPS-01: request_org_termination_export completes and returns export row'
);
select is(
  (select export_row #>> '{manifest,schema_version}' from ops01_export_result),
  '1.0',
  'OPS-01: export manifest carries schema_version 1.0'
);
select is(
  (select (export_row #>> '{manifest,patient_count}')::int from ops01_export_result),
  2,
  'OPS-01: export manifest includes all 2 Org A patients (and 0 Org B patients)'
);
select is(
  (select (export_row #>> '{manifest,lab_report_count}')::int from ops01_export_result),
  2,
  'OPS-01: export manifest includes all 2 Org A lab reports'
);
select is(
  (select length(export_row #>> '{manifest,sha256_manifest}') from ops01_export_result),
  64,
  'OPS-01: export manifest includes 64-hex-char SHA-256 digest'
);
select ok(
  (select ((export_row ->> 'due_at')::timestamptz - (export_row ->> 'requested_at')::timestamptz) = interval '30 days'
     from ops01_export_result),
  'OPS-01: termination export due_at is 30 days from requested_at (Clause 6.6)'
);
select ok(
  (select ((export_row ->> 'readonly_until')::timestamptz - (export_row ->> 'requested_at')::timestamptz) = interval '60 days'
     from ops01_export_result),
  'OPS-01: post-termination read-only window is 60 days from requested_at (Clause 6.6)'
);
reset role;

select is(
  (select count(*)::int from public.audit_log
    where org_id = '00000000-0000-0000-0000-00000000000a'
      and event_type = 'org_termination_export_requested'),
  1,
  'OPS-01: org_termination_export_requested is written to audit_log'
);

-- ===========================================================================
-- 3. OPS-02: Patient Legal Holds & Written Deletion Confirmation Certificate
-- ===========================================================================

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');

-- Place legal hold on Patient A2
select is(
  (public.set_patient_legal_hold(
    '00000000-0000-0000-0000-0000000a6002',
    true,
    'Litigation preservation order #2026-11-A2'
  ) ->> 'hold')::boolean,
  true,
  'OPS-02: org_admin places legal hold on patient A2'
);

-- Attempt deletion while under legal hold -> must fail with patient_under_legal_hold
select throws_ok(
  $$ select public.confirm_patient_data_deletion('00000000-0000-0000-0000-0000000a6002') $$,
  'P0001', 'patient_under_legal_hold',
  'OPS-02: confirm_patient_data_deletion refuses to delete patient A2 while under legal hold'
);
reset role;

-- Verify A2's clinical rows are still intact while hold is active
select is(
  (select count(*)::int from public.lab_reports where patient_id = '00000000-0000-0000-0000-0000000a6002'),
  1,
  'OPS-02: patient A2 lab_reports remain intact when legal hold blocks deletion'
);

-- Release legal hold and confirm deletion
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
select is(
  (public.set_patient_legal_hold(
    '00000000-0000-0000-0000-0000000a6002',
    false,
    null
  ) ->> 'hold')::boolean,
  false,
  'OPS-02: org_admin releases legal hold on patient A2'
);

create temp table ops02_del_cert as
  select public.confirm_patient_data_deletion('00000000-0000-0000-0000-0000000a6002') as cert;

select ok(
  (select (cert ->> 'confirmation_code') ~ '^DEL-[0-9A-F]{12}$' from ops02_del_cert),
  'OPS-02: deletion confirmation certificate generates DEL-XXXXXXXXXXXX confirmation code'
);
select ok(
  (select (cert ->> 'patient_ref') ~ '^PAT-[0-9a-f]{16}$' from ops02_del_cert),
  'OPS-02: deletion confirmation retains only opaque patient_ref (no raw PII)'
);
select is(
  (select length(cert ->> 'certificate_sha256') from ops02_del_cert),
  64,
  'OPS-02: deletion confirmation includes 64-hex-char SHA-256 certificate hash'
);
select is(
  (select (cert #>> '{summary,deleted_lab_reports}')::int from ops02_del_cert),
  1,
  'OPS-02: deletion summary records 1 deleted lab_report'
);
select is(
  (select (cert #>> '{summary,deleted_profiles}')::int from ops02_del_cert),
  1,
  'OPS-02: deletion summary records 1 deleted patient_profile'
);
select is(
  (select (cert #>> '{summary,deleted_consents}')::int from ops02_del_cert),
  1,
  'OPS-02: deletion summary records 1 deleted consent'
);
reset role;

-- Verify clinical rows are gone and patient PII was scrubbed
select is(
  (select count(*)::int from public.lab_reports where patient_id = '00000000-0000-0000-0000-0000000a6002'),
  0,
  'OPS-02: patient A2 lab_reports deleted'
);
select is(
  (select count(*)::int from public.patient_profiles where patient_id = '00000000-0000-0000-0000-0000000a6002'),
  0,
  'OPS-02: patient A2 patient_profiles deleted'
);
select is(
  (select count(*)::int from public.consents where patient_id = '00000000-0000-0000-0000-0000000a6002'),
  0,
  'OPS-02: patient A2 consents deleted'
);
select is(
  (select coalesce(display_name, '') || coalesce(mrn, '') from public.patients where id = '00000000-0000-0000-0000-0000000a6002'),
  '',
  'OPS-02: patient A2 display_name and mrn scrubbed from public.patients'
);

-- ===========================================================================
-- 4. OPS-03: 72-Hour Security Incident Notification Workflow (Clause 8.8)
-- ===========================================================================

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');

create temp table ops03_incident as
  select public.report_security_incident(
    'P1',
    'Confirmed credential stuffing spike on portal endpoint',
    'Automated credential stuffing detected and blocked at edge rate limiter; zero unauthorized sessions established.',
    true
  ) as inc;

select is(
  (select inc ->> 'severity' from ops03_incident),
  'P1',
  'OPS-03: report_security_incident records P1 severity'
);
select is(
  (select inc ->> 'status' from ops03_incident),
  'notified',
  'OPS-03: report_security_incident with p_notify_now=true marks status as notified'
);
select is(
  (select (inc ->> 'within_72h_sla')::boolean from ops03_incident),
  true,
  'OPS-03: immediate notification satisfies within_72h_sla = true'
);
select ok(
  (select ((inc ->> 'notify_deadline_at')::timestamptz - (inc ->> 'confirmed_at')::timestamptz) = interval '72 hours'
     from ops03_incident),
  'OPS-03: notify_deadline_at is exactly 72 hours after confirmed_at (Clause 8.8)'
);
reset role;

select is(
  (select count(*)::int from public.notification_outbox
    where org_id = '00000000-0000-0000-0000-00000000000a'
      and type = 'security_incident_72h_notice'
      and payload ->> 'event_type' = 'security_incident_72h_notice'),
  1,
  'OPS-03: security_incident_72h_notice is enqueued in public.notification_outbox'
);

-- ===========================================================================
-- 5. Cross-Org RLS Isolation, Role Gating & AAL2 Enforcement
-- ===========================================================================

-- Cross-org: Org Admin A cannot place legal hold on or delete Org B patient B1
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
select throws_ok(
  $$ select public.set_patient_legal_hold('00000000-0000-0000-0000-0000000b1001', true, 'Cross-org attempt') $$,
  'P0002', 'patient_not_found',
  'Cross-org: org_admin A cannot place a legal hold on Org B patient B1'
);
select throws_ok(
  $$ select public.confirm_patient_data_deletion('00000000-0000-0000-0000-0000000b1001') $$,
  'P0002', 'patient_not_found',
  'Cross-org: org_admin A cannot delete Org B patient B1'
);
reset role;

-- Non-admin roles (physician A) and AAL1 org_admin A are denied on admin RPCs
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician A
select throws_ok(
  $$ select public.get_org_monthly_usage_summary('2026-11-01'::date) $$,
  '42501', null,
  'Role gate: physician cannot call get_org_monthly_usage_summary'
);
select throws_ok(
  $$ select public.request_org_termination_export() $$,
  '42501', null,
  'Role gate: physician cannot call request_org_termination_export'
);
select throws_ok(
  $$ select public.set_patient_legal_hold('00000000-0000-0000-0000-0000000a1001', true, 'Physician attempt') $$,
  '42501', null,
  'Role gate: physician cannot call set_patient_legal_hold'
);
select throws_ok(
  $$ select public.confirm_patient_data_deletion('00000000-0000-0000-0000-0000000a1001') $$,
  '42501', null,
  'Role gate: physician cannot call confirm_patient_data_deletion'
);
select throws_ok(
  $$ select public.report_security_incident('P2', 'Physician report attempt', 'Physician should not be able to trigger org incident notices.') $$,
  '42501', null,
  'Role gate: physician cannot call report_security_incident'
);
reset role;

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal1'); -- org_admin A at AAL1
select throws_ok(
  $$ select public.get_org_monthly_usage_summary('2026-11-01'::date) $$,
  '42501', null,
  'AAL2 gate: org_admin at aal1 cannot call get_org_monthly_usage_summary'
);
select throws_ok(
  $$ select public.request_org_termination_export() $$,
  '42501', null,
  'AAL2 gate: org_admin at aal1 cannot call request_org_termination_export'
);
reset role;

-- Cross-org table SELECT isolation: Org B actor sees 0 Org A rows across all 5 new tables
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2');
select is((select count(*)::int from public.usage_months), 0, 'Cross-org RLS: physician B sees 0 usage_months rows');
select is((select count(*)::int from public.org_termination_exports), 0, 'Cross-org RLS: physician B sees 0 org_termination_exports rows');
select is((select count(*)::int from public.patient_legal_holds), 0, 'Cross-org RLS: physician B sees 0 patient_legal_holds rows');
select is((select count(*)::int from public.patient_deletion_confirmations), 0, 'Cross-org RLS: physician B sees 0 patient_deletion_confirmations rows');
select is((select count(*)::int from public.security_incidents), 0, 'Cross-org RLS: physician B sees 0 security_incidents rows');
reset role;

-- Positive SELECT control: Org Admin A at AAL2 sees own-org rows across the new tables
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
select is((select count(*)::int from public.usage_months), 2, 'Own-org RLS: org_admin A sees 2 usage_months rows');
select is((select count(*)::int from public.org_termination_exports), 1, 'Own-org RLS: org_admin A sees 1 org_termination_exports row');
select is((select count(*)::int from public.patient_deletion_confirmations), 1, 'Own-org RLS: org_admin A sees 1 patient_deletion_confirmations row');
select is((select count(*)::int from public.security_incidents), 1, 'Own-org RLS: org_admin A sees 1 security_incidents row');
reset role;

select * from finish();
rollback;
