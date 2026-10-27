-- Clara review of ecff0d3: M10 fail-open, M11 backfill, L17 revoke.
-- Written to fail before the M10/M11/L17 migration (no trigger / ensure /
-- backfill / revoke).
begin;
select no_plan();

-- L18: test-only fail hook (NOT in production migrations). Created inside this
-- transaction so rollback drops it; production db reset has no such trigger.
create or replace function public.trg_patient_self_signups_test_fail()
returns trigger
language plpgsql
as $$
begin
  if current_setting('test.fail_self_signup_marker', true) = '1' then
    raise exception 'forced marker insert failure' using errcode = 'P0001';
  end if;
  return NEW;
end;
$$;

drop trigger if exists patient_self_signups_test_fail on public.patient_self_signups;
create trigger patient_self_signups_test_fail
  before insert on public.patient_self_signups
  for each row
  execute function public.trg_patient_self_signups_test_fail();


-- L17: authenticated cannot execute is_patient_self_signup
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
select throws_ok(
  $$ select public.is_patient_self_signup('00000000-0000-0000-0000-0000000a0001') $$,
  '42501', null,
  'L17: authenticated cannot execute is_patient_self_signup'
);

-- M10: trigger marks patient-role insert in the same DB step.
reset role;
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000d10aa',
  'authenticated', 'authenticated', 'm10-trigger@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{"role":"patient"}'::jsonb, now(), now()
);

select ok(
  exists (select 1 from public.patient_self_signups where user_id = '00000000-0000-0000-0000-0000000d10aa'),
  'M10: AFTER INSERT trigger marks patient-role self-signup'
);

-- create_patient_record (SECURITY DEFINER) still refuses self-signup after L17 revoke.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select throws_ok(
  $$ select public.create_patient_record('00000000-0000-0000-0000-0000000d10aa', 'Nope', 'MRN-M10') $$,
  '42501', null,
  'L17/M10: create_patient_record still refuses self-signup via SECURITY DEFINER'
);

-- M10: forced marker failure aborts auth.users insert — no unmarked account.
reset role;
select set_config('test.fail_self_signup_marker', '1', true);
select throws_ok(
  $$ insert into auth.users (
       instance_id, id, aud, role, email, encrypted_password,
       email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
     ) values (
       '00000000-0000-0000-0000-000000000000',
       '00000000-0000-0000-0000-0000000d10bb',
       'authenticated', 'authenticated', 'm10-fail@example.test',
       extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
       now(), '{"provider":"email","providers":["email"]}'::jsonb,
       '{"role":"patient"}'::jsonb, now(), now()
     ) $$,
  'P0001', null,
  'M10: auth.users insert aborts when marker insert is forced to fail'
);
select set_config('test.fail_self_signup_marker', '0', true);
select ok(
  not exists (select 1 from auth.users where id = '00000000-0000-0000-0000-0000000d10bb'),
  'M10: no unmarked auth.users row remains after forced marker failure'
);

-- M10 ensure helper: user without patient role (trigger skips), ensure with
-- fail GUC deletes and returns 'removed' (must commit — no re-raise).
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000d10cc',
  'authenticated', 'authenticated', 'm10-ensure@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb, now(), now()
);
select ok(
  not exists (select 1 from public.patient_self_signups where user_id = '00000000-0000-0000-0000-0000000d10cc'),
  'M10 precondition: no marker when role is not patient'
);
select set_config('test.fail_self_signup_marker', '1', true);
select set_config('request.jwt.claims', json_build_object('role','service_role')::text, true);
set role service_role;
select is(
  public.ensure_patient_self_signup_marker('00000000-0000-0000-0000-0000000d10cc'),
  'removed',
  'M10: ensure_patient_self_signup_marker returns removed when marker insert forced to fail'
);
reset role;
select set_config('test.fail_self_signup_marker', '0', true);
select ok(
  not exists (select 1 from auth.users where id = '00000000-0000-0000-0000-0000000d10cc'),
  'M10: ensure deletes the account when marker insert fails'
);

-- M11: unmarked patient-type account gets marker from idempotent backfill.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000d10dd',
  'authenticated', 'authenticated', 'm11-backfill@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{"role":"patient"}'::jsonb, now(), now()
);
delete from public.patient_self_signups where user_id = '00000000-0000-0000-0000-0000000d10dd';
select ok(
  not exists (select 1 from public.patient_self_signups where user_id = '00000000-0000-0000-0000-0000000d10dd'),
  'M11 precondition: marker stripped'
);
select set_config('request.jwt.claims', json_build_object('role','service_role')::text, true);
set role service_role;
select ok(
  public.backfill_patient_self_signups() >= 1,
  'M11: backfill inserts at least the stripped patient-type account'
);
reset role;
select ok(
  exists (select 1 from public.patient_self_signups where user_id = '00000000-0000-0000-0000-0000000d10dd'),
  'M11: backfill restored the marker'
);
select set_config('request.jwt.claims', json_build_object('role','service_role')::text, true);
set role service_role;
select is(
  public.backfill_patient_self_signups(),
  0,
  'M11: second backfill is idempotent (0 new rows)'
);
reset role;

select * from finish();
rollback;
