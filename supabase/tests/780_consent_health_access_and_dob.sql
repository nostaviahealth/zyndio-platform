-- Placeholder health_data consent does not unlock labs. A direct profile
-- write cannot store an under-18 or future date of birth. Synthetic only.
begin;
select no_plan();

select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1');
select is((select count(*)::int from public.lab_reports where patient_id = '00000000-0000-0000-0000-0000000a1001'), 0,
  'without an approved health_data consent the patient sees no lab reports');
select throws_ok($$
  insert into public.lab_reports (org_id, patient_id, report_type, data)
  values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'patient_upload', '{}')
$$, '42501', null, 'without an approved health_data consent the patient cannot file a report');

reset role;
select set_config('request.jwt.claims', '', true);
select throws_ok($$
  update public.patient_profiles set date_of_birth = date '2016-01-01'
   where id = '00000000-0000-0000-0000-0000000a2001'
$$, '22023', null, 'a direct write of a 2016 date of birth is refused');
select throws_ok($$
  update public.patient_profiles set date_of_birth = current_date + 1
   where id = '00000000-0000-0000-0000-0000000a2001'
$$, '22023', null, 'a future date of birth is refused');
select throws_ok($$
  update public.patient_profiles
     set date_of_birth = (current_date - interval '18 years')::date + 1
   where id = '00000000-0000-0000-0000-0000000a2001'
$$, '22023', null, 'a date one day younger than 18 is refused');
select lives_ok($$
  update public.patient_profiles
     set date_of_birth = (current_date - interval '18 years')::date
   where id = '00000000-0000-0000-0000-0000000a2001'
$$, 'a date of exactly 18 years ago is stored');
select lives_ok($$
  update public.patient_profiles set date_of_birth = null
   where id = '00000000-0000-0000-0000-0000000a2001'
$$, 'clearing a date of birth does not invent a replacement');
select lives_ok($$
  update public.patient_profiles set data = '{"note":"still fictional"}'
   where id = '00000000-0000-0000-0000-0000000a2001'
$$, 'updating another column leaves a null date of birth alone');

select * from finish();
rollback;
