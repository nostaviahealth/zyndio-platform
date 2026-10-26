-- TC-005 pgTAP fixtures: actor rows shared by every other file in this
-- directory, plus the JWT-mocking helper that stands in for PostgREST's
-- session setup (auth.uid()/auth.jwt() just read the request.jwt.claims GUC,
-- so setting it here is equivalent to a real signed-in request).
--
-- Not wrapped in begin/rollback: every other test file runs in its own
-- transaction and needs this fixture data to already be committed.

create extension if not exists pgtap with schema extensions;

select no_plan();

create schema if not exists tests;
-- Each test file is a separate pg_prove connection/transaction that then
-- switches role via authenticate_as(); every role it might switch to needs
-- USAGE/EXECUTE on this schema up front, while the connection is still
-- whatever role pg_prove used to run the script.
grant usage on schema tests to anon, authenticated, service_role;

-- `local` scope (the `true` third argument) means each test file's own
-- begin/.../rollback wrapper resets role + claims automatically, so files
-- don't leak session state into one another even though they share a db.
create or replace function tests.authenticate_as(p_user_id uuid, p_aal text default 'aal2')
returns void
language plpgsql
as $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'sub', p_user_id::text,
      'role', 'authenticated',
      'aal', p_aal
    )::text,
    true
  );
end;
$$;

create or replace function tests.authenticate_as_anon()
returns void
language plpgsql
as $$
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
end;
$$;

-- Models a raw anon-key request where PostgREST never injected any claims
-- at all (as opposed to tests.authenticate_as_anon(), which sets an
-- explicit {"role":"anon"} claim) - auth.jwt()/auth.uid() both read NULL.
create or replace function tests.clear_authentication()
returns void
language plpgsql
as $$
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', '', true);
end;
$$;

-- ---------------------------------------------------------------------------
-- Two orgs, so every "cross-org" assertion in the per-table files has a real
-- other org to be denied access to.
-- ---------------------------------------------------------------------------

insert into public.organizations (id, name) values
  ('00000000-0000-0000-0000-00000000000a', 'Org A'),
  ('00000000-0000-0000-0000-00000000000b', 'Org B');

-- ---------------------------------------------------------------------------
-- auth.users rows for every actor (org_members/patients FK into auth.users).
-- Fictional names/emails only.
-- ---------------------------------------------------------------------------

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
select
  '00000000-0000-0000-0000-000000000000',
  u.id,
  'authenticated',
  'authenticated',
  u.email,
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  now(),
  now()
from (values
  ('00000000-0000-0000-0000-0000000a0001'::uuid, 'org-admin-a@example.test'),
  ('00000000-0000-0000-0000-0000000a0002'::uuid, 'physician-a@example.test'),
  ('00000000-0000-0000-0000-0000000a0003'::uuid, 'care-coordinator-a@example.test'),
  ('00000000-0000-0000-0000-0000000a0004'::uuid, 'read-only-a@example.test'),
  ('00000000-0000-0000-0000-0000000b0001'::uuid, 'physician-b@example.test'),
  ('00000000-0000-0000-0000-0000000a1001'::uuid, 'patient-a1@example.test'),
  ('00000000-0000-0000-0000-0000000b1001'::uuid, 'patient-b1@example.test'),
  -- not yet a patient row - several test files insert one as a staff actor,
  -- to prove INSERT policies rather than just pre-seeded SELECT visibility.
  ('00000000-0000-0000-0000-0000000a6002'::uuid, 'patient-a2@example.test')
) as u(id, email);

-- ---------------------------------------------------------------------------
-- org_members: one row per staff actor, one role per person.
-- ---------------------------------------------------------------------------

insert into public.org_members (user_id, org_id, role, status) values
  ('00000000-0000-0000-0000-0000000a0001', '00000000-0000-0000-0000-00000000000a', 'org_admin', 'active'),
  ('00000000-0000-0000-0000-0000000a0002', '00000000-0000-0000-0000-00000000000a', 'physician', 'active'),
  ('00000000-0000-0000-0000-0000000a0003', '00000000-0000-0000-0000-00000000000a', 'care_coordinator', 'active'),
  ('00000000-0000-0000-0000-0000000a0004', '00000000-0000-0000-0000-00000000000a', 'read_only', 'active'),
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-00000000000b', 'physician', 'active');

-- ---------------------------------------------------------------------------
-- patients: one per org, so cross-org denial has a real row to deny.
-- ---------------------------------------------------------------------------

insert into public.patients (id, org_id, display_name, mrn) values
  ('00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000000000a', 'Fictional Patient A1', 'MRN-A1'),
  ('00000000-0000-0000-0000-0000000b1001', '00000000-0000-0000-0000-00000000000b', 'Fictional Patient B1', 'MRN-B1');

insert into public.patient_profiles (id, org_id, patient_id, data) values
  ('00000000-0000-0000-0000-0000000a2001', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '{"note":"fictional"}'),
  ('00000000-0000-0000-0000-0000000b2001', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000b1001', '{"note":"fictional"}');

insert into public.lab_reports (id, org_id, patient_id, report_type, data) values
  ('00000000-0000-0000-0000-0000000a3001', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'basic_panel', '{"result":"fictional"}'),
  ('00000000-0000-0000-0000-0000000b3001', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000b1001', 'basic_panel', '{"result":"fictional"}');

insert into public.consents (id, org_id, patient_id, consent_type, granted) values
  ('00000000-0000-0000-0000-0000000a4001', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'data_sharing', true),
  ('00000000-0000-0000-0000-0000000b4001', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000b1001', 'data_sharing', true);

insert into public.invites (id, org_id, email, role, token_hash, invited_by) values
  ('00000000-0000-0000-0000-0000000a5001', '00000000-0000-0000-0000-00000000000a', 'invitee-a@example.test', 'physician', 'fixturehash-a', '00000000-0000-0000-0000-0000000a0001');

select ok(true, 'fixtures loaded');

select * from finish();
