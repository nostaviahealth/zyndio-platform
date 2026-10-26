-- patients: patient self select/update; physician+care_coordinator full
-- write within their org; read_only select-only within their org;
-- org_admin excluded entirely (Henry: admins manage users only).
begin;
select no_plan();

select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2'); -- patient_a1
select is(
  (select array_agg(id) from public.patients),
  array['00000000-0000-0000-0000-0000000a1001']::uuid[],
  'patient_a1 sees only their own patient row, not patient B1'
);
update public.patients set display_name = 'Updated Fictional A1' where id = '00000000-0000-0000-0000-0000000a1001';
select is(
  (select display_name from public.patients where id = '00000000-0000-0000-0000-0000000a1001'),
  'Updated Fictional A1',
  'patient_a1 can update their own display_name'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select is(
  (select count(*) from public.patients)::int,
  0,
  'org_admin_a cannot see any patient row - admins manage users only'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select is(
  (select array_agg(id) from public.patients),
  array['00000000-0000-0000-0000-0000000a1001']::uuid[],
  'physician_a sees only org A patients, not patient B1 (cross-org denied)'
);
insert into public.patients (id, org_id, display_name, mrn)
  values ('00000000-0000-0000-0000-0000000a6002', '00000000-0000-0000-0000-00000000000a', 'Fictional Patient A2', 'MRN-A2');
select is(
  (select display_name from public.patients where id = '00000000-0000-0000-0000-0000000a6002'),
  'Fictional Patient A2',
  'physician_a can insert a new patient into their own org'
);
update public.patients set mrn = 'MRN-A2-UPDATED' where id = '00000000-0000-0000-0000-0000000a6002';
select is(
  (select mrn from public.patients where id = '00000000-0000-0000-0000-0000000a6002'),
  'MRN-A2-UPDATED',
  'physician_a can update a patient in their own org'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2'); -- care_coordinator_a
select is(
  (select display_name from public.patients where id = '00000000-0000-0000-0000-0000000a1001'),
  'Updated Fictional A1',
  'care_coordinator_a can read org A patients too'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2'); -- read_only_a
select is(
  (select array_agg(id) from public.patients),
  array['00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-0000000a6002']::uuid[],
  'read_only_a can see org A patients'
);
update public.patients set mrn = 'READONLY-HACKED' where id = '00000000-0000-0000-0000-0000000a1001';
select isnt(
  (select mrn from public.patients where id = '00000000-0000-0000-0000-0000000a1001'),
  'READONLY-HACKED',
  'read_only_a cannot update a patient row'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2'); -- physician_b, cross-org
select is(
  (select display_name from public.patients where id = '00000000-0000-0000-0000-0000000a1001'),
  null,
  'physician_b (cross-org physician) cannot read patient A1'
);
update public.patients set mrn = 'CROSSORG-HACKED' where id = '00000000-0000-0000-0000-0000000a1001';
select isnt(
  (select mrn from public.patients where id = '00000000-0000-0000-0000-0000000a1001'),
  'CROSSORG-HACKED',
  'physician_b (cross-org) cannot update patient A1'
);

select * from finish();
rollback;
