-- Cross-cutting aal1-vs-aal2 sweep. Every staff/admin policy in the
-- per-table files above ANDs has_aal2() - rather than repeat the same
-- aal1-denied assertion in all nine table files, this file hits a
-- representative sample of those policies once each, and also confirms the
-- two policies that deliberately do NOT require aal2 (org_members self-row,
-- organizations self-row) still work at aal1 - a signed-in-but-not-yet-MFA'd
-- user needs to see their own role/status during the sign-in flow itself.
begin;
select no_plan();

-- org_members_admin_select: org_admin_a at aal1 loses admin visibility...
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal1');
select is(
  (select array_agg(user_id) from public.org_members),
  array['00000000-0000-0000-0000-0000000a0001']::uuid[],
  'org_admin_a at aal1 falls back to self_select only - admin_select requires aal2'
);
-- ...and regains it at aal2.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
select is(
  (select count(*) from public.org_members)::int,
  4,
  'org_admin_a at aal2 sees all org A members again'
);

-- There is no org_members UPDATE path left for any client role at any aal
-- (review group A, H1 - see 020_org_members.sql) - UPDATE is revoked from
-- authenticated outright, so this is a permission error at aal1 same as aal2.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal1');
select throws_ok(
  $$ update public.org_members set status = 'deactivated' where user_id = '00000000-0000-0000-0000-0000000a0004' $$,
  null, null,
  'org_admin_a at aal1 cannot update a teammate''s row - no direct UPDATE path exists at all'
);

-- patients_staff_write_select requires aal2.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal1'); -- physician_a
select is(
  (select count(*) from public.patients)::int,
  0,
  'physician_a at aal1 cannot see any patient row - staff policies require aal2'
);

-- patient_profiles staff select requires aal2.
select is(
  (select count(*) from public.patient_profiles)::int,
  0,
  'physician_a at aal1 cannot see any patient_profiles row'
);

-- lab_reports staff select requires aal2.
select is(
  (select count(*) from public.lab_reports)::int,
  0,
  'physician_a at aal1 cannot see any lab_reports row'
);

-- consents staff select requires aal2.
select is(
  (select count(*) from public.consents)::int,
  0,
  'physician_a at aal1 cannot see any consents row'
);

-- invites_admin_select requires aal2.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal1'); -- org_admin_a
select is(
  (select count(*) from public.invites)::int,
  0,
  'org_admin_a at aal1 cannot see invites - invites_admin_select requires aal2'
);

-- Deliberate exceptions: these do NOT require aal2, by design.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal1'); -- physician_a, not yet MFA'd
select is(
  (select array_agg(user_id) from public.org_members),
  array['00000000-0000-0000-0000-0000000a0002']::uuid[],
  'org_members_self_select works at aal1 - a not-yet-MFA''d user can see their own role/status'
);
select is(
  (select array_agg(id) from public.organizations),
  array['00000000-0000-0000-0000-00000000000a']::uuid[],
  'organizations_self_select works at aal1 too'
);

select * from finish();
rollback;
