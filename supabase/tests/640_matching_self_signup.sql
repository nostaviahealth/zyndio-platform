-- TC-012 PSU-TO-16 (Clara Approve condition): physician / care_coordinator
-- cannot create_patient_record for a self-signup account.
begin;
select plan(5);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000a30cc',
  'authenticated', 'authenticated', 'self-signup-psu16@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{"role":"patient"}'::jsonb, now(), now()
);

insert into public.patient_self_signups (user_id)
values ('00000000-0000-0000-0000-0000000a30cc');

select ok(
  public.is_patient_self_signup('00000000-0000-0000-0000-0000000a30cc'),
  'PSU-TO-16 precondition: self-signup marker present'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select throws_ok(
  $$ select public.create_patient_record('00000000-0000-0000-0000-0000000a30cc', 'Should Not Exist', 'MRN-SS') $$,
  '42501', null,
  'PSU-TO-16: physician cannot create_patient_record for a self-signup account'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2'); -- care_coordinator_a
select throws_ok(
  $$ select public.create_patient_record('00000000-0000-0000-0000-0000000a30cc', 'Should Not Exist', 'MRN-SS') $$,
  '42501', null,
  'PSU-TO-16: care_coordinator cannot create_patient_record for a self-signup account'
);

reset role;
select set_config('request.jwt.claims', '', true);
select is(
  (select count(*)::int from public.patients where id = '00000000-0000-0000-0000-0000000a30cc'),
  0,
  'PSU-TO-16: no patients row was created for the self-signup account'
);

-- Non-self-signup unbound account still works (control).
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000a30dd',
  'authenticated', 'authenticated', 'clinic-provisionable@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb, now(), now()
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select lives_ok(
  $$ select public.create_patient_record('00000000-0000-0000-0000-0000000a30dd', 'Clinic Provisioned', 'MRN-CP') $$,
  'PSU-TO-16 control: physician can still create_patient_record for a non-self-signup account'
);

select * from finish();
rollback;
