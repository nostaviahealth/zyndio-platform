-- lab_reports: patient self select+insert only (no self-update - a report
-- is immutable from the patient side once uploaded); staff write for
-- physician+care_coordinator; read_only select; org_admin excluded.
begin;
select no_plan();

-- SYNTHETIC FIXTURE. Not a legal document. This file still proves the patient
-- can see and file their own report once that grant exists.
insert into public.consent_documents (consent_type, version, document, title, summary, body, required, is_placeholder, published_at)
values ('health_data', 'synthetic-fixture', 'synthetic_health_data_fixture', 'Synthetic fixture',
        'SYNTHETIC FIXTURE - not a legally approved document',
        'SYNTHETIC FIXTURE - not a legally approved document. Not for patient use.',
        false, false, now())
on conflict (consent_type, version) do nothing;
insert into public.consents (org_id, patient_id, consent_type, document, version, granted)
values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001',
        'health_data', 'synthetic_health_data_fixture', 'synthetic-fixture', true);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2'); -- patient_a1
select is(
  (select array_agg(id) from public.lab_reports),
  array['00000000-0000-0000-0000-0000000a3001']::uuid[],
  'patient_a1 sees only their own lab report'
);
insert into public.lab_reports (id, org_id, patient_id, report_type, data)
  values ('00000000-0000-0000-0000-0000000a6004', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'lipid_panel', '{"result":"fictional"}');
select is(
  (select report_type from public.lab_reports where id = '00000000-0000-0000-0000-0000000a6004'),
  'lipid_panel',
  'patient_a1 can insert their own lab report'
);
update public.lab_reports set report_type = 'tampered' where id = '00000000-0000-0000-0000-0000000a6004';
select isnt(
  (select report_type from public.lab_reports where id = '00000000-0000-0000-0000-0000000a6004'),
  'tampered',
  'patient_a1 cannot update a lab report once uploaded (no self-update policy)'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select is(
  (select count(*) from public.lab_reports)::int,
  0,
  'org_admin_a cannot see any lab_reports row'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select is(
  (select count(*) from public.lab_reports where org_id = '00000000-0000-0000-0000-00000000000b')::int,
  0,
  'physician_a cannot see org B lab reports (cross-org denied)'
);
update public.lab_reports set report_type = 'reviewed' where id = '00000000-0000-0000-0000-0000000a6004';
select is(
  (select report_type from public.lab_reports where id = '00000000-0000-0000-0000-0000000a6004'),
  'reviewed',
  'physician_a (staff) can update a lab report in their own org'
);

-- Review group A, finding H2 (Clara PR #4 pre-review; Henry's binding
-- ruling): read_only gets no clinical detail at the DB level - its SELECT on
-- lab_reports was dropped entirely. This used to assert read_only_a could
-- read the row; that's wrong per Henry and is corrected here, not weakened.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2'); -- read_only_a
select is(
  (select count(*) from public.lab_reports)::int,
  0,
  'read_only_a cannot read any lab_reports row - no clinical detail at the DB level'
);
select throws_ok(
  $$ insert into public.lab_reports (id, org_id, patient_id, report_type, data)
     values ('00000000-0000-0000-0000-0000000a6005', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'x', '{}') $$,
  '42501', null,
  'read_only_a cannot insert a lab report'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2'); -- physician_b, cross-org
select is(
  (select count(*) from public.lab_reports where patient_id = '00000000-0000-0000-0000-0000000a1001')::int,
  0,
  'physician_b cannot see patient A1''s lab reports'
);

select * from finish();
rollback;
