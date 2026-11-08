-- APP-04: patient profile (name, DOB, sex at birth, height, units).
--   * update_patient_profile validates every field (adult DOB, allowed
--     sex-at-birth values, 50-272 cm, imperial|metric) and writes the name
--     to patients.display_name and the rest to the patient's profile row;
--   * my_patient_profile reads it back; onboarding status reports
--     profile_complete;
--   * column checks back the RPC up for direct writes;
--   * own clinic staff see the new columns, other patients/clinics don't;
--   * unlinked accounts and anon can't use the RPCs.
begin;
select no_plan();

select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1'); -- patient_a1
select is((public.patient_onboarding_status() ->> 'profile_complete')::boolean, false,
  'a new patient''s profile is incomplete');
select is(public.my_patient_profile() ->> 'display_name', 'Fictional Patient A1',
  'my_patient_profile returns the name staff entered');
select is(public.my_patient_profile() ->> 'date_of_birth', null, 'DOB not set yet');

-- validation
select throws_ok($$ select public.update_patient_profile('', '1980-05-01', 'female', 165, 'imperial') $$,
  '22023', 'invalid_display_name', 'a blank name is refused');
select throws_ok($$ select public.update_patient_profile(repeat('x', 81), '1980-05-01', 'female', 165, 'imperial') $$,
  '22023', 'invalid_display_name', 'a name over 80 characters is refused');
select throws_ok($$ select public.update_patient_profile('Fictional Patient A1', (current_date - interval '17 years')::date, 'female', 165, 'imperial') $$,
  '22023', 'invalid_date_of_birth', 'an under-18 date of birth is refused (adult program)');
select throws_ok($$ select public.update_patient_profile('Fictional Patient A1', current_date + 1, 'female', 165, 'imperial') $$,
  '22023', 'invalid_date_of_birth', 'a future date of birth is refused');
select throws_ok($$ select public.update_patient_profile('Fictional Patient A1', '1899-12-31', 'female', 165, 'imperial') $$,
  '22023', 'invalid_date_of_birth', 'a date of birth before 1900 is refused');
select throws_ok($$ select public.update_patient_profile('Fictional Patient A1', '1980-05-01', 'unknown', 165, 'imperial') $$,
  '22023', 'invalid_sex_at_birth', 'an unknown sex-at-birth value is refused');
select throws_ok($$ select public.update_patient_profile('Fictional Patient A1', '1980-05-01', 'female', 49, 'imperial') $$,
  '22023', 'invalid_height', 'a height under 50 cm is refused');
select throws_ok($$ select public.update_patient_profile('Fictional Patient A1', '1980-05-01', 'female', 273, 'imperial') $$,
  '22023', 'invalid_height', 'a height over 272 cm is refused');
select throws_ok($$ select public.update_patient_profile('Fictional Patient A1', '1980-05-01', 'female', 165, 'stones') $$,
  '22023', 'invalid_unit_system', 'an unknown unit system is refused');

-- happy path
select is(
  public.update_patient_profile('  Fictional Patient A1 Updated ', '1980-05-01', 'female', 165.04, 'imperial'),
  '{"display_name":"Fictional Patient A1 Updated","date_of_birth":"1980-05-01","sex_at_birth":"female","height_cm":165.0,"unit_system":"imperial"}'::jsonb,
  'a valid profile saves (name trimmed, height to 0.1 cm) and comes back');
select is((public.patient_onboarding_status() ->> 'profile_complete')::boolean, true,
  'once every field is set the profile is complete');
select is((select display_name from public.patients where id = '00000000-0000-0000-0000-0000000a1001'),
  'Fictional Patient A1 Updated', 'the name is stored on patients.display_name (what staff see)');
select is((select count(*)::int from public.patient_profiles where patient_id = '00000000-0000-0000-0000-0000000a1001'), 1,
  'the existing profile row is updated, not duplicated');

select is(
  public.update_patient_profile('Fictional Patient A1', '1980-05-01', 'intersex', 180, 'metric') ->> 'unit_system',
  'metric', 'a second save edits the same profile (settings edit)');
select is((select count(*)::int from public.patient_profiles where patient_id = '00000000-0000-0000-0000-0000000a1001'), 1,
  'still one profile row');

-- direct writes are backed by column checks
select throws_ok($$ update public.patient_profiles set height_cm = 400 where patient_id = '00000000-0000-0000-0000-0000000a1001' $$,
  '23514', null, 'a direct write of an impossible height is refused by the column check');
select throws_ok($$ update public.patient_profiles set sex_at_birth = 'x' where patient_id = '00000000-0000-0000-0000-0000000a1001' $$,
  '23514', null, 'a direct write of an unknown sex-at-birth is refused by the column check');
reset role;

-- another patient's save never touches patient_a1
select tests.authenticate_as('00000000-0000-0000-0000-0000000b1001', 'aal1'); -- patient_b1
select is(public.update_patient_profile('Fictional Patient B1', '1975-01-15', 'male', 182.3, 'imperial') ->> 'height_cm',
  '182.3', 'patient_b1 saves their own profile');
select is((select count(*)::int from public.patient_profiles where patient_id = '00000000-0000-0000-0000-0000000a1001'), 0,
  'patient_b1 cannot see patient_a1''s profile');
reset role;

-- a patient with no profile row yet gets one, in their own clinic
delete from public.patient_profiles where patient_id = '00000000-0000-0000-0000-0000000b1001';
select tests.authenticate_as('00000000-0000-0000-0000-0000000b1001', 'aal1');
select is(public.update_patient_profile('Fictional Patient B1', '1975-01-15', 'male', 182.3, 'imperial') ->> 'sex_at_birth',
  'male', 'with no profile row, saving creates one');
reset role;
select is((select org_id from public.patient_profiles where patient_id = '00000000-0000-0000-0000-0000000b1001'),
  '00000000-0000-0000-0000-00000000000b'::uuid, 'the new profile row is pinned to the patient''s own clinic');

-- staff in the patient's clinic see the new columns; other clinics don't
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select is((select sex_at_birth from public.patient_profiles where patient_id = '00000000-0000-0000-0000-0000000a1001'),
  'intersex', 'own-clinic physician reads sex at birth (reference ranges)');
select is((select height_cm from public.patient_profiles where patient_id = '00000000-0000-0000-0000-0000000a1001'),
  180.0::numeric, 'own-clinic physician reads height (BMI)');
select throws_ok($$ select public.update_patient_profile('x', '1980-05-01', 'female', 165, 'imperial') $$,
  '42501', null, 'staff cannot use the patient profile RPC');
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2'); -- physician_b
select is((select count(*)::int from public.patient_profiles where patient_id = '00000000-0000-0000-0000-0000000a1001'), 0,
  'other-clinic staff cannot see the profile');
reset role;

-- unlinked / anon
select tests.authenticate_as('00000000-0000-0000-0000-0000000a9001', 'aal1'); -- no patients row
select throws_ok($$ select public.my_patient_profile() $$, '42501', null, 'an unlinked account has no profile');
select throws_ok($$ select public.update_patient_profile('x', '1980-05-01', 'female', 165, 'imperial') $$,
  '42501', null, 'an unlinked account cannot save a profile');
reset role;
select tests.authenticate_as_anon();
select throws_ok($$ select public.my_patient_profile() $$, '42501', null, 'anon cannot read a profile');
reset role;

select * from finish();
rollback;
