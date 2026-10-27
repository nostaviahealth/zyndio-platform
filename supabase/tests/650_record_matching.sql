-- TC-012 matching: PSU-TO-01..15 (+ replay/kill/notices). PSU-TO-16 covered in 640.
begin;
select no_plan();

-- H-M2: fictional Vault pepper (rolled back with the test transaction).
delete from vault.secrets where name = 'link_code_pepper';
select vault.create_secret(
  'tc012-pgtap-fictional-pepper-not-for-prod',
  'link_code_pepper',
  'pgTAP fictional pepper — never a real value'
);

-- Self-signup verified users (no patients row).
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
(
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000c2001',
  'authenticated', 'authenticated', 'jordan.link@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{"role":"patient"}'::jsonb, now(), now()
),
(
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000c2002',
  'authenticated', 'authenticated', 'morgan.link@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{"role":"patient"}'::jsonb, now(), now()
),
(
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000c2003',
  'authenticated', 'authenticated', 'avery.link@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{"role":"patient"}'::jsonb, now(), now()
);

insert into public.patient_self_signups (user_id) values
  ('00000000-0000-0000-0000-0000000c2001'),
  ('00000000-0000-0000-0000-0000000c2002'),
  ('00000000-0000-0000-0000-0000000c2003')
on conflict (user_id) do nothing;

-- PSU-TO-15: verified self-signup, unlinked, reads zero clinical rows.
select tests.authenticate_as('00000000-0000-0000-0000-0000000c2001');
select is(
  (select count(*)::int from public.patients),
  0,
  'PSU-TO-15: unlinked self-signup sees zero patients rows'
);
select is(
  (select count(*)::int from public.patient_profiles),
  0,
  'PSU-TO-15: unlinked self-signup sees zero patient_profiles'
);
select is(
  (select count(*)::int from public.lab_reports),
  0,
  'PSU-TO-15: unlinked self-signup sees zero lab_reports'
);

-- PSU-TO-01..03: no bind RPC accepts email/name/DOB — only code redeem exists.
select hasnt_function(
  'public', 'bind_by_email',
  'PSU-TO-01: no bind_by_email function'
);
select hasnt_function(
  'public', 'bind_by_name',
  'PSU-TO-02: no bind_by_name function'
);
select hasnt_function(
  'public', 'bind_by_dob',
  'PSU-TO-03: no bind_by_dob function'
);

-- Issue OTP for Jordan (b1001) via service_role.
reset role;
select set_config('request.jwt.claims', json_build_object('role','service_role')::text, true);
set role service_role;

select lives_ok(
  $$ select public.issue_telehealth_link_otp(
       '00000000-0000-0000-0000-0000000c2001',
       'th_test_jr_001',
       '00000000-0000-0000-0000-00000000000a',
       '123456',
       10
     ) $$,
  'issue telehealth OTP for Jordan'
);

-- PSU-TO-06 / TO-13: Avery (b1003) cannot redeem Jordan's OTP (scoped to issued_to).
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000c2003');
select is(
  (public.redeem_telehealth_link_code('123456')->>'ok')::boolean,
  false,
  'PSU-TO-06/13: other account cannot redeem OTP issued to Jordan'
);

-- Jordan redeems successfully.
select tests.authenticate_as('00000000-0000-0000-0000-0000000c2001');
select is(
  (public.redeem_telehealth_link_code('123456')->>'ok')::boolean,
  true,
  'Jordan redeems telehealth OTP and binds'
);

select ok(
  public.current_patient_linked(),
  'after bind, current_patient_linked is true'
);

select is(
  (select telehealth_patient_id from public.patient_record_links
   where app_user_id = '00000000-0000-0000-0000-0000000c2001' and status = 'active'),
  'th_test_jr_001',
  'active link points at th_test_jr_001'
);

-- Dual-channel notices on bind (Henry / Clara #6).
reset role;
select ok(
  exists (
    select 1 from public.telehealth_message_outbox
    where telehealth_patient_id = 'th_test_jr_001'
      and body like '%linked to a Zyndio app account%'
  ),
  'PSU notice: clinic-channel link message enqueued'
);
select ok(
  exists (
    select 1 from public.notification_outbox
    where user_id = '00000000-0000-0000-0000-0000000c2001'
      and type = 'patient_record_linked'
  ),
  'PSU notice: account-email link message enqueued'
);

-- PSU-TO-04: replay used code fails.
select tests.authenticate_as('00000000-0000-0000-0000-0000000c2002');
select is(
  (public.redeem_telehealth_link_code('123456')->>'ok')::boolean,
  false,
  'PSU-TO-04: replaying a used OTP fails'
);

-- PSU-TO-07: second account cannot bind same telehealth id with clinic code.
reset role;
select set_config('request.jwt.claims', json_build_object('role','service_role')::text, true);
set role service_role;
select public.issue_clinic_link_code(
  'th_test_jr_001',
  '00000000-0000-0000-0000-00000000000a',
  'ABCD-EFGH',
  'clinic_staff',
  72
);
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000c2002');
select is(
  public.redeem_clinic_link_code('ABCDEFGH')->>'error',
  'conflict',
  'PSU-TO-07: clinic code for already-linked record rejects second app account'
);

-- Fresh clinic code for Avery's record.
reset role;
select set_config('request.jwt.claims', json_build_object('role','service_role')::text, true);
set role service_role;
select public.issue_clinic_link_code(
  'th_test_av_001',
  '00000000-0000-0000-0000-00000000000a',
  'CLINIC-DEMO-7K4',
  'clinic_staff',
  72
);
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000c2003');
select is(
  (public.redeem_clinic_link_code('CLINICDEMO7K4')->>'ok')::boolean,
  true,
  'PSU-TO-11: patient-scoped clinic code binds without email/name/DOB selectors'
);

-- PSU-TO-05: five wrong OTP tries kill the code.
reset role;
select set_config('request.jwt.claims', '', true);
-- New user for kill test (must insert as superuser, not service_role)
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000c2004',
  'authenticated', 'authenticated', 'killotp@link.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{"role":"patient"}'::jsonb, now(), now()
);
insert into public.patient_self_signups (user_id)
values ('00000000-0000-0000-0000-0000000c2004')
on conflict (user_id) do nothing;
select set_config('request.jwt.claims', json_build_object('role','service_role')::text, true);
set role service_role;
select public.issue_telehealth_link_otp(
  '00000000-0000-0000-0000-0000000c2004',
  'th_test_kill_001',
  '00000000-0000-0000-0000-00000000000a',
  '654321',
  10
);
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000c2004');
select is((public.redeem_telehealth_link_code('000000')->>'ok')::boolean, false, 'wrong try 1');
select is((public.redeem_telehealth_link_code('000001')->>'ok')::boolean, false, 'wrong try 2');
select is((public.redeem_telehealth_link_code('000002')->>'ok')::boolean, false, 'wrong try 3');
select is((public.redeem_telehealth_link_code('000003')->>'ok')::boolean, false, 'wrong try 4');
select is((public.redeem_telehealth_link_code('000004')->>'ok')::boolean, false, 'wrong try 5 — kills code');
reset role;
select ok(
  exists (
    select 1 from public.patient_link_codes
    where issued_to_app_user_id = '00000000-0000-0000-0000-0000000c2004'
      and method = 'telehealth_otp'
      and killed_at is not null
  ),
  'PSU-TO-05: OTP killed_at set after 5 wrong tries'
);
select tests.authenticate_as('00000000-0000-0000-0000-0000000c2004');
select is(
  (public.redeem_telehealth_link_code('654321')->>'ok')::boolean,
  false,
  'PSU-TO-05: correct code rejected after kill'
);

-- PSU-TO-08: unlink then re-link with new code; old code dead.
select tests.authenticate_as('00000000-0000-0000-0000-0000000c2001');
select is((public.unlink_patient_record()->>'ok')::boolean, true, 'unlink Jordan');
select ok(not public.current_patient_linked(), 'after unlink, current_patient_linked is false');

reset role;
select set_config('request.jwt.claims', json_build_object('role','service_role')::text, true);
set role service_role;
select public.issue_telehealth_link_otp(
  '00000000-0000-0000-0000-0000000c2001',
  'th_test_jr_001',
  '00000000-0000-0000-0000-00000000000a',
  '777777',
  10
);
-- Old used code still dead:
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000c2001');
select is(
  (public.redeem_telehealth_link_code('123456')->>'ok')::boolean,
  false,
  'PSU-TO-08: old used OTP cannot re-bind after unlink'
);
select is(
  (public.redeem_telehealth_link_code('777777')->>'ok')::boolean,
  true,
  'PSU-TO-08: fresh OTP re-links after unlink'
);

-- PSU-TO-14: enqueue review does not leak match count to client shape (server-side only).
reset role;
select set_config('request.jwt.claims', json_build_object('role','service_role')::text, true);
set role service_role;
select lives_ok(
  $$ select public.enqueue_patient_link_review(
       '00000000-0000-0000-0000-0000000c2002',
       '00000000-0000-0000-0000-00000000000a',
       'ambiguous_match',
       '{"candidates":["th_a","th_b"]}'::jsonb
     ) $$,
  'PSU-TO-14: ambiguous match enqueues opaque review row'
);

-- PSU-TO-09: Jordan cannot see Avery's link row details via RLS (own rows only).
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000c2001');
select is(
  (select count(*)::int from public.patient_record_links
   where telehealth_patient_id = 'th_test_av_001'),
  0,
  'PSU-TO-09: Jordan cannot read Avery link rows'
);

-- Authenticated cannot call issue_* directly.
select throws_ok(
  $$ select public.issue_telehealth_link_otp(
       '00000000-0000-0000-0000-0000000c2001',
       'th_x', '00000000-0000-0000-0000-00000000000a', '111111', 10) $$,
  '42501', null,
  'issue_telehealth_link_otp is service_role only'
);

select * from finish();
rollback;
