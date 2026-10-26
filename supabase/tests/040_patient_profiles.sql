-- patient_profiles: same shape as patients (self select/update, staff
-- write for physician+care_coordinator, read_only select, org_admin
-- excluded), keyed by patient_id rather than id.
begin;
select no_plan();

select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2'); -- patient_a1
select is(
  (select array_agg(id) from public.patient_profiles),
  array['00000000-0000-0000-0000-0000000a2001']::uuid[],
  'patient_a1 sees only their own profile row'
);
update public.patient_profiles set data = '{"note":"updated by patient"}' where patient_id = '00000000-0000-0000-0000-0000000a1001';
select is(
  (select data->>'note' from public.patient_profiles where patient_id = '00000000-0000-0000-0000-0000000a1001'),
  'updated by patient',
  'patient_a1 can update their own profile data'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select is(
  (select count(*) from public.patient_profiles)::int,
  0,
  'org_admin_a cannot see any patient_profiles row'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select is(
  (select array_agg(id) from public.patient_profiles),
  array['00000000-0000-0000-0000-0000000a2001']::uuid[],
  'physician_a sees only org A profiles, not org B (cross-org denied)'
);
insert into public.patient_profiles (id, org_id, patient_id, data)
  values ('00000000-0000-0000-0000-0000000a6003', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '{"note":"added by physician"}');
select is(
  (select data->>'note' from public.patient_profiles where id = '00000000-0000-0000-0000-0000000a6003'),
  'added by physician',
  'physician_a can insert a profile row in their own org'
);
update public.patient_profiles set data = '{"note":"edited by physician"}' where id = '00000000-0000-0000-0000-0000000a6003';
select is(
  (select data->>'note' from public.patient_profiles where id = '00000000-0000-0000-0000-0000000a6003'),
  'edited by physician',
  'physician_a can update a profile row in their own org'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2'); -- read_only_a
update public.patient_profiles set data = '{"note":"hacked"}' where id = '00000000-0000-0000-0000-0000000a6003';
select isnt(
  (select data->>'note' from public.patient_profiles where id = '00000000-0000-0000-0000-0000000a6003'),
  'hacked',
  'read_only_a cannot update a profile row'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2'); -- physician_b, cross-org
select is(
  (select count(*) from public.patient_profiles where org_id = '00000000-0000-0000-0000-00000000000a')::int,
  0,
  'physician_b cannot see any org A profile row'
);

select * from finish();
rollback;
