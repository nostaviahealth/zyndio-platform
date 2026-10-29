-- TC-015 fix round (28 Oct): physician_roster_base() is the ONE named
-- SECURITY DEFINER exception to "Leo ruling 3" (invoker everywhere), taken in
-- 34fdd87 for the 5,000-patient budget. See
-- docs/architecture/ADR-0001-roster-base-security-definer.md.
--
-- Part 1 - Henry's conditions for the exception (structural):
--   a. search_path pinned to '' (empty) - every name in the body is
--      schema-qualified. FAILS on 34fdd87 (pinned to 'pg_catalog, public').
--   b. no EXECUTE for PUBLIC or anon (explicit revoke).
--   c. no parameters at all: the clinic can only come from the caller's own
--      session (current_org_id() -> org_members by auth.uid()), never from an
--      argument, and a forged org claim in the JWT is ignored.
-- Part 2 - Clara's gate test: the definer gate itself must return ZERO org-A
-- rows for each of: a physician from another clinic, an org_admin, an aal1
-- session, a patient, a deactivated member, and anon. Passes on the gated
-- code; the saved replays prove it FAILS with the gate removed
-- (docs/evidence/tc-015/failfirst-replay/pgtap-722-gate-removed*.txt).
--
-- Fixtures are built in this file's own transaction under TC-015-namespaced
-- UUIDs (...722...) and rolled back at the end. Fictional data only.
begin;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);

-- ---------------------------------------------------------------------------
-- Part 1: structural conditions.
-- ---------------------------------------------------------------------------
select is(
  (select proconfig from pg_proc where oid = 'public.physician_roster_base()'::regprocedure),
  array['search_path=""']::text[],
  'physician_roster_base(): search_path is pinned to empty (schema-qualified body)'
);
select ok(
  (select prosecdef from pg_proc where oid = 'public.physician_roster_base()'::regprocedure),
  'physician_roster_base() is the named SECURITY DEFINER exception'
);
select ok(
  not has_function_privilege('anon', 'public.physician_roster_base()', 'execute'),
  'anon cannot execute physician_roster_base()'
);
select ok(
  not exists (
    select 1
    from pg_proc p, lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
    where p.oid = 'public.physician_roster_base()'::regprocedure
      and a.grantee = 0 and a.privilege_type = 'EXECUTE'
  ),
  'PUBLIC has no EXECUTE on physician_roster_base()'
);
select ok(
  has_function_privilege('authenticated', 'public.physician_roster_base()', 'execute'),
  'authenticated keeps EXECUTE (the invoker roster RPCs call it as the caller)'
);
select is(
  (select pronargs::int from pg_proc where oid = 'public.physician_roster_base()'::regprocedure),
  0,
  'physician_roster_base() takes no parameters (clinic comes only from the session)'
);

-- ---------------------------------------------------------------------------
-- Fixtures: two extra org-A patients (so org A has >= 3 visible rows) and a
-- deactivated org-A physician.
-- ---------------------------------------------------------------------------
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
select
  '00000000-0000-0000-0000-000000000000', u.id,
  'authenticated', 'authenticated', u.email,
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf', 4)),
  now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now()
from (values
  ('00000000-0000-0000-0000-000000722201'::uuid, 'gate-patient-1@example.test'),
  ('00000000-0000-0000-0000-000000722202'::uuid, 'gate-patient-2@example.test'),
  ('00000000-0000-0000-0000-000000722d01'::uuid, 'gate-deactivated@example.test')
) as u(id, email);

insert into public.patients (id, org_id, display_name, mrn) values
  ('00000000-0000-0000-0000-000000722201', '00000000-0000-0000-0000-00000000000a', 'Gate Alpha', 'ZP-7221'),
  ('00000000-0000-0000-0000-000000722202', '00000000-0000-0000-0000-00000000000a', 'Gate Bravo', 'ZP-7222');

insert into public.org_members (user_id, org_id, role, status) values
  ('00000000-0000-0000-0000-000000722d01', '00000000-0000-0000-0000-00000000000a', 'physician', 'deactivated');

-- Positive control, so the zero-row assertions below are not vacuous.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select ok(
  (select count(*) from public.physician_roster_base()
    where patient_id in ('00000000-0000-0000-0000-0000000a1001',
                         '00000000-0000-0000-0000-000000722201',
                         '00000000-0000-0000-0000-000000722202')) = 3,
  'control: physician_a (aal2, active, org A) sees all 3 org-A gate patients'
);

-- ---------------------------------------------------------------------------
-- Part 2: the gate. Zero org-A rows for each non-entitled caller.
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2'); -- physician_b
select is(
  (select count(*)::int from public.physician_roster_base()
    where patient_id in ('00000000-0000-0000-0000-0000000a1001',
                         '00000000-0000-0000-0000-000000722201',
                         '00000000-0000-0000-0000-000000722202')),
  0,
  'gate: a physician from another clinic (org B, aal2) gets zero org-A rows'
);

-- Forged org claims in the JWT must not move the caller into org A.
reset role;
select set_config('role', 'authenticated', true);
select set_config('request.jwt.claims', json_build_object(
  'sub', '00000000-0000-0000-0000-0000000b0001', 'role', 'authenticated', 'aal', 'aal2',
  'org_id', '00000000-0000-0000-0000-00000000000a',
  'app_metadata', json_build_object('org_id', '00000000-0000-0000-0000-00000000000a')
)::text, true);
select is(
  (select count(*)::int from public.physician_roster_base()
    where patient_id in ('00000000-0000-0000-0000-0000000a1001',
                         '00000000-0000-0000-0000-000000722201',
                         '00000000-0000-0000-0000-000000722202')),
  0,
  'gate: a forged org_id claim (top-level and app_metadata) is ignored - clinic comes from org_members only'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select is(
  (select count(*)::int from public.physician_roster_base()),
  0,
  'gate: an org_admin (org A, aal2) gets zero rows'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal1'); -- physician_a, aal1
select is(
  (select count(*)::int from public.physician_roster_base()),
  0,
  'gate: an aal1 session (physician_a without MFA) gets zero rows'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2'); -- patient a1001
select is(
  (select count(*)::int from public.physician_roster_base()),
  0,
  'gate: a patient (a1001, aal2) gets zero rows'
);

select tests.authenticate_as('00000000-0000-0000-0000-000000722d01', 'aal2'); -- deactivated physician
select is(
  (select count(*)::int from public.physician_roster_base()),
  0,
  'gate: a deactivated member (org A physician, aal2) gets zero rows'
);

select tests.authenticate_as_anon();
select throws_ok(
  'select count(*) from public.physician_roster_base()',
  '42501',
  null,
  'gate: anon cannot call physician_roster_base() at all (zero rows - permission denied)'
);
select throws_ok(
  $$select count(*) from public.physician_patient_roster(null, 'all', 'recent', 50, 0)$$,
  '42501',
  null,
  'gate: anon cannot call the physician_patient_roster() RPC either'
);

select * from finish();
rollback;
