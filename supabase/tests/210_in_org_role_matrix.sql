-- In-org role matrix: for each role, in its OWN org, the allowed vs denied
-- ops per table exactly as 20261026120100_tc005_rls.sql intends - one
-- assertion per (role, table, op) cell, plus a closing aal1 sweep proving
-- every staff role loses all clinical/admin access below aal2. Complements
-- 200_cross_org_matrix.sql (which proves the cross-tenant axis); this file
-- proves the same-tenant allow/deny shape the policies were designed for:
--   organizations     - every role sees its own org row; no writes for
--                        anyone (no insert/update/delete policy exists)
--   org_members       - org_admin sees + updates the whole org; everyone
--                        else sees only their own row; no insert/delete for
--                        anyone (membership changes go through
--                        change_member_role()/invite-acceptance instead)
--   patients/profiles/
--   lab_reports/
--   consents          - org_admin: none at all ("admins manage users
--                        only"); physician/care_coordinator: full
--                        read+write (no delete - there is no delete policy
--                        anywhere); read_only: read-only; patient: own row
--                        only (lab_reports has no self-update - immutable
--                        once uploaded; patients/patient_profiles have no
--                        self-insert - staff-created)
--   invites           - org_admin select-only; everyone else: nothing
--
-- UPDATE/DELETE with no matching policy affect 0 rows silently (the USING
-- clause defaults to false); INSERT with no matching WITH CHECK raises
-- (a row must be accepted or rejected, it can't be silently dropped) - that
-- asymmetry is why some "denied" cells below assert 0-rows and others
-- assert throws_ok.
begin;
select no_plan();

-- ---------------------------------------------------------------------------
-- org_admin_a
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');

select is((select name from public.organizations where id = '00000000-0000-0000-0000-00000000000a'), 'Org A',
  'org_admin_a x organizations x select: allowed (own org)');
update public.organizations set name = 'Hacked' where id = '00000000-0000-0000-0000-00000000000a';
select is((select name from public.organizations where id = '00000000-0000-0000-0000-00000000000a'), 'Org A',
  'org_admin_a x organizations x update: denied, 0 rows (no policy for anyone)');
delete from public.organizations where id = '00000000-0000-0000-0000-00000000000a';
select is((select name from public.organizations where id = '00000000-0000-0000-0000-00000000000a'), 'Org A',
  'org_admin_a x organizations x delete: denied, 0 rows (no policy for anyone)');
select throws_ok(
  $$ insert into public.organizations (id, name) values ('00000000-0000-0000-0000-0000000f0001', 'x') $$,
  null, null, 'org_admin_a x organizations x insert: denied (no policy for anyone)');

select is((select count(*) from public.org_members)::int, 4,
  'org_admin_a x org_members x select: allowed, sees all 4 org A members');
update public.org_members set status = 'deactivated' where user_id = '00000000-0000-0000-0000-0000000a0003';
select is((select status from public.org_members where user_id = '00000000-0000-0000-0000-0000000a0003'), 'deactivated',
  'org_admin_a x org_members x update: allowed (own org, aal2)');
delete from public.org_members where user_id = '00000000-0000-0000-0000-0000000a0002';
select is((select count(*) from public.org_members where user_id = '00000000-0000-0000-0000-0000000a0002')::int, 1,
  'org_admin_a x org_members x delete: denied, 0 rows (no delete policy)');
select throws_ok(
  $$ insert into public.org_members (user_id, org_id, role, status)
     values ('00000000-0000-0000-0000-0000000a9001', '00000000-0000-0000-0000-00000000000a', 'physician', 'active') $$,
  null, null, 'org_admin_a x org_members x insert: denied (no insert policy - invite-acceptance only)');

select is((select count(*) from public.patients)::int, 0, 'org_admin_a x patients x select: denied (admins manage users only)');
update public.patients set display_name = 'Hacked' where id = '00000000-0000-0000-0000-0000000a1001';
select is((select count(*) from public.patients where id = '00000000-0000-0000-0000-0000000a1001' and display_name = 'Hacked')::int, 0,
  'org_admin_a x patients x update: denied, 0 rows');
delete from public.patients where id = '00000000-0000-0000-0000-0000000a1001';
select throws_ok(
  $$ insert into public.patients (id, org_id, display_name, mrn)
     values ('00000000-0000-0000-0000-0000000a9001', '00000000-0000-0000-0000-00000000000a', 'x', 'x') $$,
  null, null, 'org_admin_a x patients x insert: denied');

select is((select count(*) from public.patient_profiles)::int, 0, 'org_admin_a x patient_profiles x select: denied');
update public.patient_profiles set data = '{"hacked":true}' where id = '00000000-0000-0000-0000-0000000a2001';
select throws_ok(
  $$ insert into public.patient_profiles (id, org_id, patient_id, data)
     values ('00000000-0000-0000-0000-0000000f0003', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '{}') $$,
  null, null, 'org_admin_a x patient_profiles x insert: denied');

select is((select count(*) from public.lab_reports)::int, 0, 'org_admin_a x lab_reports x select: denied');
update public.lab_reports set report_type = 'hacked' where id = '00000000-0000-0000-0000-0000000a3001';
select throws_ok(
  $$ insert into public.lab_reports (id, org_id, patient_id, report_type, data)
     values ('00000000-0000-0000-0000-0000000f0004', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'x', '{}') $$,
  null, null, 'org_admin_a x lab_reports x insert: denied');

select is((select count(*) from public.consents)::int, 0, 'org_admin_a x consents x select: denied');
update public.consents set granted = false where id = '00000000-0000-0000-0000-0000000a4001';
select throws_ok(
  $$ insert into public.consents (id, org_id, patient_id, consent_type, granted)
     values ('00000000-0000-0000-0000-0000000f0005', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'x', true) $$,
  null, null, 'org_admin_a x consents x insert: denied');

select is((select array_agg(id) from public.invites), array['00000000-0000-0000-0000-0000000a5001']::uuid[],
  'org_admin_a x invites x select: allowed (own org)');
update public.invites set role = 'read_only' where id = '00000000-0000-0000-0000-0000000a5001';
select is((select role::text from public.invites where id = '00000000-0000-0000-0000-0000000a5001'), 'physician',
  'org_admin_a x invites x update: denied, 0 rows (no policy)');
select throws_ok(
  $$ insert into public.invites (id, org_id, email, role, token_hash)
     values ('00000000-0000-0000-0000-0000000f0002', '00000000-0000-0000-0000-00000000000a', 'x@example.test', 'physician', 'x') $$,
  null, null, 'org_admin_a x invites x insert: denied (Edge Function only)');

-- (org_admin_a's attempted writes above all matched 0 rows - the a1001/
-- a2001/a3001/a4001 fixture rows are unchanged, as physician_a's first
-- assertion below confirms by reading them back.)

-- ---------------------------------------------------------------------------
-- physician_a and care_coordinator_a share the same allow/deny shape
-- (physician/care_coordinator are both full-read-write staff roles).
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a

select is((select name from public.organizations where id = '00000000-0000-0000-0000-00000000000a'), 'Org A',
  'physician_a x organizations x select: allowed (own org)');
update public.organizations set name = 'Hacked' where id = '00000000-0000-0000-0000-00000000000a';
select is((select name from public.organizations where id = '00000000-0000-0000-0000-00000000000a'), 'Org A',
  'physician_a x organizations x update: denied, 0 rows (no policy for anyone)');

select is((select array_agg(user_id) from public.org_members), array['00000000-0000-0000-0000-0000000a0002']::uuid[],
  'physician_a x org_members x select: only own row (not an admin)');
update public.org_members set status = 'deactivated' where user_id = '00000000-0000-0000-0000-0000000a0002';
select is((select status from public.org_members where user_id = '00000000-0000-0000-0000-0000000a0002'), 'active',
  'physician_a x org_members x update: denied, 0 rows (not an admin, even on own row)');
select throws_ok(
  $$ insert into public.org_members (user_id, org_id, role, status)
     values ('00000000-0000-0000-0000-0000000a9001', '00000000-0000-0000-0000-00000000000a', 'physician', 'active') $$,
  null, null, 'physician_a x org_members x insert: denied');

select is((select display_name from public.patients where id = '00000000-0000-0000-0000-0000000a1001'), 'Fictional Patient A1',
  'physician_a x patients x select: allowed (own org)');
insert into public.patients (id, org_id, display_name, mrn)
  values ('00000000-0000-0000-0000-0000000a6002', '00000000-0000-0000-0000-00000000000a', 'Fictional Patient A2', 'MRN-A2');
select is((select display_name from public.patients where id = '00000000-0000-0000-0000-0000000a6002'), 'Fictional Patient A2',
  'physician_a x patients x insert: allowed (own org)');
update public.patients set display_name = 'Updated A2' where id = '00000000-0000-0000-0000-0000000a6002';
select is((select display_name from public.patients where id = '00000000-0000-0000-0000-0000000a6002'), 'Updated A2',
  'physician_a x patients x update: allowed (own org)');
delete from public.patients where id = '00000000-0000-0000-0000-0000000a6002';
select is((select count(*) from public.patients where id = '00000000-0000-0000-0000-0000000a6002')::int, 1,
  'physician_a x patients x delete: denied, 0 rows (no delete policy)');

insert into public.patient_profiles (id, org_id, patient_id, data)
  values ('00000000-0000-0000-0000-0000000a6003', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a6002', '{"note":"fictional"}');
select is((select data from public.patient_profiles where id = '00000000-0000-0000-0000-0000000a6003'), '{"note":"fictional"}'::jsonb,
  'physician_a x patient_profiles x insert: allowed (own org)');
update public.patient_profiles set data = '{"note":"updated"}' where id = '00000000-0000-0000-0000-0000000a6003';
select is((select data from public.patient_profiles where id = '00000000-0000-0000-0000-0000000a6003'), '{"note":"updated"}'::jsonb,
  'physician_a x patient_profiles x update: allowed (own org)');
delete from public.patient_profiles where id = '00000000-0000-0000-0000-0000000a6003';
select is((select count(*) from public.patient_profiles where id = '00000000-0000-0000-0000-0000000a6003')::int, 1,
  'physician_a x patient_profiles x delete: denied, 0 rows');

insert into public.lab_reports (id, org_id, patient_id, report_type, data)
  values ('00000000-0000-0000-0000-0000000a6004', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a6002', 'basic_panel', '{}');
select is((select report_type from public.lab_reports where id = '00000000-0000-0000-0000-0000000a6004'), 'basic_panel',
  'physician_a x lab_reports x insert: allowed (own org)');
update public.lab_reports set report_type = 'updated_panel' where id = '00000000-0000-0000-0000-0000000a6004';
select is((select report_type from public.lab_reports where id = '00000000-0000-0000-0000-0000000a6004'), 'updated_panel',
  'physician_a x lab_reports x update: allowed (own org)');
delete from public.lab_reports where id = '00000000-0000-0000-0000-0000000a6004';
select is((select count(*) from public.lab_reports where id = '00000000-0000-0000-0000-0000000a6004')::int, 1,
  'physician_a x lab_reports x delete: denied, 0 rows');

insert into public.consents (id, org_id, patient_id, consent_type, granted)
  values ('00000000-0000-0000-0000-0000000a6005', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a6002', 'data_sharing', true);
select is((select granted from public.consents where id = '00000000-0000-0000-0000-0000000a6005'), true,
  'physician_a x consents x insert: allowed (own org)');
update public.consents set granted = false where id = '00000000-0000-0000-0000-0000000a6005';
select is((select granted from public.consents where id = '00000000-0000-0000-0000-0000000a6005'), false,
  'physician_a x consents x update: allowed (own org)');
delete from public.consents where id = '00000000-0000-0000-0000-0000000a6005';
select is((select count(*) from public.consents where id = '00000000-0000-0000-0000-0000000a6005')::int, 1,
  'physician_a x consents x delete: denied, 0 rows');

select is((select count(*) from public.invites)::int, 0, 'physician_a x invites x select: denied (not an admin)');
select throws_ok(
  $$ insert into public.invites (id, org_id, email, role, token_hash)
     values ('00000000-0000-0000-0000-0000000f0006', '00000000-0000-0000-0000-00000000000a', 'x@example.test', 'physician', 'x') $$,
  null, null, 'physician_a x invites x insert: denied');

-- Restore the seed between role blocks (as the table owner, which has
-- BYPASSRLS) so each role's counts start from the same fixture state; this
-- only resets data, it changes no assertion.
reset role;
select set_config('request.jwt.claims', '', true);
delete from public.consents where id = '00000000-0000-0000-0000-0000000a6005';
delete from public.lab_reports where id = '00000000-0000-0000-0000-0000000a6004';
delete from public.patient_profiles where id = '00000000-0000-0000-0000-0000000a6003';
delete from public.patients where id = '00000000-0000-0000-0000-0000000a6002';
update public.org_members set status = 'active' where user_id = '00000000-0000-0000-0000-0000000a0003';

-- care_coordinator_a: same shape as physician_a on clinical tables - sampled
-- across all four rather than repeating every op, since the policies are
-- the identical `in ('physician', 'care_coordinator')` clause.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2'); -- care_coordinator_a

select is((select display_name from public.patients where id = '00000000-0000-0000-0000-0000000a1001'), 'Fictional Patient A1',
  'care_coordinator_a x patients x select: allowed (own org)');
update public.patients set display_name = 'Updated by CC' where id = '00000000-0000-0000-0000-0000000a1001';
select is((select display_name from public.patients where id = '00000000-0000-0000-0000-0000000a1001'), 'Updated by CC',
  'care_coordinator_a x patients x update: allowed (own org)');
delete from public.patients where id = '00000000-0000-0000-0000-0000000a1001';
select is((select count(*) from public.patients where id = '00000000-0000-0000-0000-0000000a1001')::int, 1,
  'care_coordinator_a x patients x delete: denied, 0 rows');

select is((select count(*) from public.patient_profiles)::int, 1, 'care_coordinator_a x patient_profiles x select: allowed (own org)');
update public.patient_profiles set data = '{"note":"updated by cc"}' where id = '00000000-0000-0000-0000-0000000a2001';
select is((select data from public.patient_profiles where id = '00000000-0000-0000-0000-0000000a2001'), '{"note":"updated by cc"}'::jsonb,
  'care_coordinator_a x patient_profiles x update: allowed (own org)');

select is((select count(*) from public.lab_reports)::int, 1, 'care_coordinator_a x lab_reports x select: allowed (own org)');
update public.lab_reports set report_type = 'updated_by_cc' where id = '00000000-0000-0000-0000-0000000a3001';
select is((select report_type from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'), 'updated_by_cc',
  'care_coordinator_a x lab_reports x update: allowed (own org)');

select is((select count(*) from public.consents)::int, 1, 'care_coordinator_a x consents x select: allowed (own org)');
update public.consents set granted = false where id = '00000000-0000-0000-0000-0000000a4001';
select is((select granted from public.consents where id = '00000000-0000-0000-0000-0000000a4001'), false,
  'care_coordinator_a x consents x update: allowed (own org)');

select is((select count(*) from public.invites)::int, 0, 'care_coordinator_a x invites x select: denied (not an admin)');

select is((select array_agg(user_id) from public.org_members), array['00000000-0000-0000-0000-0000000a0003']::uuid[],
  'care_coordinator_a x org_members x select: only own row (not an admin)');

-- Restore the seed after care_coordinator_a's allowed updates (see above).
reset role;
select set_config('request.jwt.claims', '', true);
update public.patients set display_name = 'Fictional Patient A1' where id = '00000000-0000-0000-0000-0000000a1001';
update public.patient_profiles set data = '{"note":"fictional"}' where id = '00000000-0000-0000-0000-0000000a2001';
update public.lab_reports set report_type = 'basic_panel' where id = '00000000-0000-0000-0000-0000000a3001';
update public.consents set granted = true where id = '00000000-0000-0000-0000-0000000a4001';

-- ---------------------------------------------------------------------------
-- read_only_a: select-only on clinical tables, no writes anywhere.
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2');

select is((select name from public.organizations where id = '00000000-0000-0000-0000-00000000000a'), 'Org A',
  'read_only_a x organizations x select: allowed (own org)');

select is((select array_agg(user_id) from public.org_members), array['00000000-0000-0000-0000-0000000a0004']::uuid[],
  'read_only_a x org_members x select: only own row (not an admin)');

select is((select display_name from public.patients where id = '00000000-0000-0000-0000-0000000a1001'), 'Fictional Patient A1',
  'read_only_a x patients x select: allowed (own org)');
update public.patients set display_name = 'Hacked' where id = '00000000-0000-0000-0000-0000000a1001';
select is((select display_name from public.patients where id = '00000000-0000-0000-0000-0000000a1001'), 'Fictional Patient A1',
  'read_only_a x patients x update: denied, 0 rows');
select throws_ok(
  $$ insert into public.patients (id, org_id, display_name, mrn)
     values ('00000000-0000-0000-0000-0000000a9001', '00000000-0000-0000-0000-00000000000a', 'x', 'x') $$,
  null, null, 'read_only_a x patients x insert: denied');

select is((select count(*) from public.patient_profiles)::int, 1, 'read_only_a x patient_profiles x select: allowed (own org)');
update public.patient_profiles set data = '{"hacked":true}' where id = '00000000-0000-0000-0000-0000000a2001';
select throws_ok(
  $$ insert into public.patient_profiles (id, org_id, patient_id, data)
     values ('00000000-0000-0000-0000-0000000f0007', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '{}') $$,
  null, null, 'read_only_a x patient_profiles x insert: denied');

select is((select count(*) from public.lab_reports)::int, 1, 'read_only_a x lab_reports x select: allowed (own org)');
select throws_ok(
  $$ insert into public.lab_reports (id, org_id, patient_id, report_type, data)
     values ('00000000-0000-0000-0000-0000000f0008', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'x', '{}') $$,
  null, null, 'read_only_a x lab_reports x insert: denied');

select is((select count(*) from public.consents)::int, 1, 'read_only_a x consents x select: allowed (own org)');
select throws_ok(
  $$ insert into public.consents (id, org_id, patient_id, consent_type, granted)
     values ('00000000-0000-0000-0000-0000000f0009', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'x', true) $$,
  null, null, 'read_only_a x consents x insert: denied');

select is((select count(*) from public.invites)::int, 0, 'read_only_a x invites x select: denied (not an admin)');

-- ---------------------------------------------------------------------------
-- patient_a1: own rows only, across the four patient-owned tables; no
-- visibility into organizations/org_members/invites at all (no org_members
-- row of their own).
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');

select is((select count(*) from public.organizations)::int, 0,
  'patient_a1 x organizations x select: denied (no org_members row, current_org_id() is null)');
select is((select count(*) from public.org_members)::int, 0,
  'patient_a1 x org_members x select: denied (not a member row)');
select is((select count(*) from public.invites)::int, 0, 'patient_a1 x invites x select: denied');

select is((select display_name from public.patients where id = '00000000-0000-0000-0000-0000000a1001'), 'Fictional Patient A1',
  'patient_a1 x patients x select: allowed (own row)');
update public.patients set display_name = 'Updated by self' where id = '00000000-0000-0000-0000-0000000a1001';
select is((select display_name from public.patients where id = '00000000-0000-0000-0000-0000000a1001'), 'Updated by self',
  'patient_a1 x patients x update: allowed (own row)');
select throws_ok(
  $$ insert into public.patients (id, org_id, display_name, mrn)
     values ('00000000-0000-0000-0000-0000000a9001', '00000000-0000-0000-0000-00000000000a', 'x', 'x') $$,
  null, null, 'patient_a1 x patients x insert: denied (no patient-self-insert policy)');

select is((select count(*) from public.patient_profiles)::int, 1, 'patient_a1 x patient_profiles x select: allowed (own row)');
update public.patient_profiles set data = '{"note":"updated by self"}' where patient_id = '00000000-0000-0000-0000-0000000a1001';
select is((select data from public.patient_profiles where patient_id = '00000000-0000-0000-0000-0000000a1001'), '{"note":"updated by self"}'::jsonb,
  'patient_a1 x patient_profiles x update: allowed (own row)');
select throws_ok(
  $$ insert into public.patient_profiles (id, org_id, patient_id, data)
     values ('00000000-0000-0000-0000-0000000f0010', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '{}') $$,
  null, null, 'patient_a1 x patient_profiles x insert: denied (no patient-self-insert policy)');

select is((select count(*) from public.lab_reports)::int, 1, 'patient_a1 x lab_reports x select: allowed (own row)');
insert into public.lab_reports (id, org_id, patient_id, report_type, data)
  values ('00000000-0000-0000-0000-0000000f0011', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'self_upload', '{}');
select is((select report_type from public.lab_reports where id = '00000000-0000-0000-0000-0000000f0011'), 'self_upload',
  'patient_a1 x lab_reports x insert: allowed (own row)');
update public.lab_reports set report_type = 'tampered' where id = '00000000-0000-0000-0000-0000000f0011';
select is((select report_type from public.lab_reports where id = '00000000-0000-0000-0000-0000000f0011'), 'self_upload',
  'patient_a1 x lab_reports x update: denied, 0 rows (immutable once uploaded)');

select is((select count(*) from public.consents)::int, 1, 'patient_a1 x consents x select: allowed (own row)');
insert into public.consents (id, org_id, patient_id, consent_type, granted)
  values ('00000000-0000-0000-0000-0000000f0012', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'marketing', false);
select is((select granted from public.consents where id = '00000000-0000-0000-0000-0000000f0012'), false,
  'patient_a1 x consents x insert: allowed (own row)');
update public.consents set granted = true where id = '00000000-0000-0000-0000-0000000f0012';
select is((select granted from public.consents where id = '00000000-0000-0000-0000-0000000f0012'), true,
  'patient_a1 x consents x update: allowed (own row)');

-- ---------------------------------------------------------------------------
-- aal1 sweep: every staff role loses all clinical/admin access below aal2.
-- (150_aal2_gating.sql already samples this once each; here it's asserted
-- per role, across every clinical table, in one place.)
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal1'); -- org_admin_a
select is((select count(*) from public.org_members)::int, 1, 'org_admin_a x aal1: org_members falls back to self-row only');
select is((select count(*) from public.invites)::int, 0, 'org_admin_a x aal1: no invites visibility');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal1'); -- physician_a
select is((select count(*) from public.patients)::int, 0, 'physician_a x aal1: no patients access');
select is((select count(*) from public.patient_profiles)::int, 0, 'physician_a x aal1: no patient_profiles access');
select is((select count(*) from public.lab_reports)::int, 0, 'physician_a x aal1: no lab_reports access');
select is((select count(*) from public.consents)::int, 0, 'physician_a x aal1: no consents access');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal1'); -- care_coordinator_a
select is((select count(*) from public.patients)::int, 0, 'care_coordinator_a x aal1: no patients access');
select is((select count(*) from public.patient_profiles)::int, 0, 'care_coordinator_a x aal1: no patient_profiles access');
select is((select count(*) from public.lab_reports)::int, 0, 'care_coordinator_a x aal1: no lab_reports access');
select is((select count(*) from public.consents)::int, 0, 'care_coordinator_a x aal1: no consents access');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal1'); -- read_only_a
select is((select count(*) from public.patients)::int, 0, 'read_only_a x aal1: no patients access');
select is((select count(*) from public.patient_profiles)::int, 0, 'read_only_a x aal1: no patient_profiles access');
select is((select count(*) from public.lab_reports)::int, 0, 'read_only_a x aal1: no lab_reports access');
select is((select count(*) from public.consents)::int, 0, 'read_only_a x aal1: no consents access');

-- ---------------------------------------------------------------------------
-- Only ACTIVE members get staff access (policy fix 20261026120200): a
-- deactivated or invited physician at aal2 sees no clinical rows and no
-- org-scoped rows, but can still read their own membership row.
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', '', true);
update public.org_members set status = 'deactivated' where user_id = '00000000-0000-0000-0000-0000000a0002';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select is((select count(*) from public.patients)::int, 0, 'deactivated physician_a x patients x select: denied');
select is((select count(*) from public.lab_reports)::int, 0, 'deactivated physician_a x lab_reports x select: denied');
select is((select count(*) from public.organizations)::int, 0, 'deactivated physician_a x organizations x select: denied');
select is((select status from public.org_members where user_id = '00000000-0000-0000-0000-0000000a0002'), 'deactivated',
  'deactivated physician_a x org_members x select: own row still visible');
reset role;
select set_config('request.jwt.claims', '', true);
update public.org_members set status = 'invited' where user_id = '00000000-0000-0000-0000-0000000a0002';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select is((select count(*) from public.patients)::int, 0, 'invited (not yet active) physician_a x patients x select: denied');
select throws_ok(
  $$ insert into public.patients (id, org_id, display_name, mrn)
     values ('00000000-0000-0000-0000-0000000a9002', '00000000-0000-0000-0000-00000000000a', 'x', 'x') $$,
  null, null, 'invited physician_a x patients x insert: denied');

select * from finish();
rollback;
