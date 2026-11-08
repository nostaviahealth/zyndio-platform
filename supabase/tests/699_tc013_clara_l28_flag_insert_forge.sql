-- Clara L28: INSERT into lab_reports must not plant a forged Needs-review
-- flag. The protect trigger only ran on UPDATE, so a linked patient or an
-- in-clinic physician / care_coordinator could INSERT with needs_review =
-- true and arbitrary flagged_by / flagged_at, with no audit row.
-- Non-RPC inserts force needs_review = false and null the flag columns;
-- a normal insert (defaults) is unchanged.
begin;
select no_plan();

-- SYNTHETIC FIXTURE so the patient insert path is reachable.
insert into public.consent_documents (consent_type, version, document, title, summary, body, required, is_placeholder, published_at)
values ('health_data', 'synthetic-fixture', 'synthetic_health_data_fixture', 'Synthetic fixture',
        'SYNTHETIC FIXTURE - not a legally approved document',
        'SYNTHETIC FIXTURE - not a legally approved document. Not for patient use.',
        false, false, now());
insert into public.consents (org_id, patient_id, consent_type, document, version, granted)
values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001',
        'health_data', 'synthetic_health_data_fixture', 'synthetic-fixture', true);

-- Patient insert with a forged flag is stripped.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2'); -- patient_a1 (linked)
insert into public.lab_reports (
  id, org_id, patient_id, report_type, data,
  needs_review, flagged_by, flagged_at
) values (
  '00000000-0000-0000-0000-0000000a3081',
  '00000000-0000-0000-0000-00000000000a',
  '00000000-0000-0000-0000-0000000a1001',
  'l28_patient_forge',
  '{}',
  true,
  '00000000-0000-0000-0000-0000000a0002',
  '2000-01-01T00:00:00Z'
);
select is(
  (select needs_review from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3081'),
  false,
  'patient INSERT with forged needs_review ends up false'
);
select is(
  (select flagged_by from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3081'),
  null,
  'patient INSERT with forged flagged_by ends up null'
);
select is(
  (select flagged_at from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3081'),
  null,
  'patient INSERT with forged flagged_at ends up null'
);

-- Staff (care_coordinator) insert with a forged flag is stripped the same way.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2'); -- care_coordinator_a
insert into public.lab_reports (
  id, org_id, patient_id, report_type, data,
  needs_review, flagged_by, flagged_at
) values (
  '00000000-0000-0000-0000-0000000a3082',
  '00000000-0000-0000-0000-00000000000a',
  '00000000-0000-0000-0000-0000000a1001',
  'l28_staff_forge',
  '{}',
  true,
  '00000000-0000-0000-0000-0000000a0001',
  '2001-02-03T04:05:06Z'
);
select is(
  (select needs_review from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3082'),
  false,
  'staff INSERT with forged needs_review ends up false'
);
select is(
  (select flagged_by from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3082'),
  null,
  'staff INSERT with forged flagged_by ends up null'
);
select is(
  (select flagged_at from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3082'),
  null,
  'staff INSERT with forged flagged_at ends up null'
);

-- Normal insert (no flag columns) is unaffected.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
insert into public.lab_reports (id, org_id, patient_id, report_type, data)
values (
  '00000000-0000-0000-0000-0000000a3083',
  '00000000-0000-0000-0000-00000000000a',
  '00000000-0000-0000-0000-0000000a1001',
  'l28_normal',
  '{}'
);
select is(
  (select needs_review from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3083'),
  false,
  'normal INSERT keeps default needs_review = false'
);
select is(
  (select flagged_by from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3083'),
  null,
  'normal INSERT keeps flagged_by null'
);
select is(
  (select flagged_at from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3083'),
  null,
  'normal INSERT keeps flagged_at null'
);
select is(
  (select report_type from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3083'),
  'l28_normal',
  'normal INSERT still writes the report row'
);

-- Forged inserts must not produce a flag audit row.
reset role;
select set_config('request.jwt.claims', '', true);
select is(
  (select count(*)::int from public.audit_log
    where event_type = 'lab_report_flagged_needs_review'
      and metadata->>'lab_report_id' in (
        '00000000-0000-0000-0000-0000000a3081',
        '00000000-0000-0000-0000-0000000a3082'
      )),
  0,
  'forged INSERT path writes no lab_report_flagged_needs_review audit row'
);

select * from finish();
rollback;
