-- PSU-TO-10: concurrent double-bind — unique indexes + deterministic conflict.
begin;
select no_plan();

-- H-M2: fictional Vault pepper (rolled back with the test transaction).
delete from vault.secrets where name = 'link_code_pepper';
select vault.create_secret(
  'tc012-pgtap-fictional-pepper-not-for-prod',
  'link_code_pepper',
  'pgTAP fictional pepper — never a real value'
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
(
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000e1001',
  'authenticated', 'authenticated', 'to10.a@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{"role":"patient"}'::jsonb, now(), now()
),
(
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000e1002',
  'authenticated', 'authenticated', 'to10.b@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{"role":"patient"}'::jsonb, now(), now()
);

insert into public.patient_self_signups (user_id) values
  ('00000000-0000-0000-0000-0000000e1001'),
  ('00000000-0000-0000-0000-0000000e1002')
on conflict (user_id) do nothing;

insert into public.patient_record_links (
  id, app_user_id, org_id, telehealth_patient_id, status, linked_at, proof_method
) values (
  '00000000-0000-0000-0000-0000000e2001',
  '00000000-0000-0000-0000-0000000e1001',
  '00000000-0000-0000-0000-00000000000a',
  'th_to10_shared',
  'active', now(), 'clinic_code'
);

select throws_ok(
  $$ insert into public.patient_record_links (
       id, app_user_id, org_id, telehealth_patient_id, status, linked_at, proof_method
     ) values (
       '00000000-0000-0000-0000-0000000e2002',
       '00000000-0000-0000-0000-0000000e1002',
       '00000000-0000-0000-0000-00000000000a',
       'th_to10_shared',
       'active', now(), 'clinic_code'
     ) $$,
  '23505', null,
  'PSU-TO-10: second active link for same telehealth_patient_id is rejected (unique index)'
);

select throws_ok(
  $$ insert into public.patient_record_links (
       id, app_user_id, org_id, telehealth_patient_id, status, linked_at, proof_method
     ) values (
       '00000000-0000-0000-0000-0000000e2003',
       '00000000-0000-0000-0000-0000000e1001',
       '00000000-0000-0000-0000-00000000000a',
       'th_to10_other',
       'active', now(), 'clinic_code'
     ) $$,
  '23505', null,
  'PSU-TO-10: second active link for same app_user_id is rejected (unique index)'
);

select is(
  (select count(*)::int from public.patient_record_links
    where telehealth_patient_id = 'th_to10_shared' and status = 'active'),
  1,
  'PSU-TO-10: exactly one active binding remains for the contended telehealth id'
);

-- Loser redeem via clinic code → deterministic conflict (same path as TO-07 race).
select set_config('request.jwt.claims', json_build_object('role','service_role')::text, true);
set role service_role;
select public.issue_clinic_link_code(
  'th_to10_shared',
  '00000000-0000-0000-0000-00000000000a',
  'TO10-RACE1',
  'clinic_staff',
  72
);
reset role;

select tests.authenticate_as('00000000-0000-0000-0000-0000000e1002');
select is(
  public.redeem_clinic_link_code('TO10RACE1')->>'error',
  'conflict',
  'PSU-TO-10: loser redeem gets deterministic conflict error'
);
reset role;

select * from finish();
rollback;
