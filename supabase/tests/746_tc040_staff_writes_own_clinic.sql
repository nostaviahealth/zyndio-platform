-- TC-040: clinic staff write lab reports, consents and patient profiles only
-- about patients of their OWN clinic; patient_id / org_id can't be changed by
-- a client once set; lab_results has no client write path; the internal
-- record-linking helpers can't be called by clients (audit, card item 5).
-- Clara PR #33 r1 M1 attack (physician B files a clinic-B row naming clinic-A
-- patient A1 and A1's PDF, or re-points a clinic-B row at A1) is the core
-- case. Probes (widened policies) live only in this rolled-back transaction.
-- Fictional data only.
begin;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);

-- Fixture actors: physician A a0002, coordinator A a0003 (clinic A); physician
-- B b0001 (clinic B); patients A1 a1001 (A) and B1 b1001 (B). Fixture rows:
-- lab_reports a3001/b3001, consents a4001/b4001, patient_profiles a2001/b2001.
-- Same-clinic patient A2 a6002 gets a patients row here.
insert into public.patients (id, org_id, display_name, mrn) values
  ('00000000-0000-0000-0000-0000000a6002', '00000000-0000-0000-0000-00000000000a', 'Fictional Patient A2', 'MRN-A2-746');
-- A1's PDF in storage (as storage-api would write it for A1).
insert into storage.objects (bucket_id, name) values
  ('lab-reports', '00000000-0000-0000-0000-0000000a1001/46a00000-0000-4000-8000-000000000001.pdf');
-- Legacy/forged clinic-B rows about A1 (written service-side, as M1 could
-- have left behind before this fix).
insert into public.lab_reports (id, org_id, patient_id, report_type, data) values
  ('00000000-0000-0000-0000-00000046b301', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000a1001', 'forged', '{}');
insert into public.consents (id, org_id, patient_id, consent_type, granted) values
  ('00000000-0000-0000-0000-00000046b401', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000a1001', 'forged', true);
insert into public.patient_profiles (id, org_id, patient_id, data) values
  ('00000000-0000-0000-0000-00000046b201', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000a1001', '{}');
-- A1's own second consent (touched only by A1 below).
insert into public.consents (id, org_id, patient_id, consent_type, granted) values
  ('00000000-0000-0000-0000-00000046a401', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'marketing', true);
-- A brand-new account with no clinic and no link yet (helper-abuse case).
insert into auth.users (id, email, email_confirmed_at, aud, role) values
  ('00000000-0000-0000-0000-000000046c01', 'tc040-new-account@example.test', now(), 'authenticated', 'authenticated');

create temp table tc040_seen (who text, n int);
grant all on tc040_seen to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Cross-clinic INSERT (card item 1, 3): physician B about clinic-A patient A1
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2');
select throws_ok($$ insert into public.lab_reports (org_id, patient_id, report_type, data) values
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000a1001', 'basic_panel', '{}') $$,
  '42501', null, 'physician B cannot file a lab report about clinic-A patient A1');
select throws_ok($$ insert into public.lab_reports (org_id, patient_id, report_type, data, pdf_path) values
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000a1001', 'basic_panel', '{}',
   '00000000-0000-0000-0000-0000000a1001/46a00000-0000-4000-8000-000000000001.pdf') $$,
  '42501', null, 'M1: physician B cannot create the forged row naming A1''s PDF');
select throws_ok($$ insert into public.consents (org_id, patient_id, consent_type, granted) values
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000a1001', 'data_sharing', true) $$,
  '42501', null, 'physician B cannot record a consent for clinic-A patient A1');
select throws_ok($$ insert into public.patient_profiles (org_id, patient_id, data) values
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000a1001', '{}') $$,
  '42501', null, 'physician B cannot create a profile for clinic-A patient A1');
select throws_ok($$ insert into public.lab_reports (org_id, patient_id, report_type, data) values
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000b1001', 'basic_panel', '{}'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000a1001', 'basic_panel', '{}') $$,
  '42501', null, 'a multi-row insert with one cross-clinic row is refused as a whole');
select is((select count(*)::int from storage.objects
            where name = '00000000-0000-0000-0000-0000000a1001/46a00000-0000-4000-8000-000000000001.pdf'),
  0, 'M1 end to end: physician B still cannot open A1''s PDF');
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2');
select throws_ok($$ insert into public.consents (org_id, patient_id, consent_type, granted) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000b1001', 'data_sharing', true) $$,
  '42501', null, 'care coordinator A cannot record a consent for clinic-B patient B1');
select throws_ok($$ insert into public.lab_reports (org_id, patient_id, report_type, data) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000b1001', 'basic_panel', '{}') $$,
  '42501', null, 'care coordinator A cannot file a lab report about clinic-B patient B1');
select throws_ok($$ insert into public.patient_profiles (org_id, patient_id, data) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000b1001', '{}') $$,
  '42501', null, 'care coordinator A cannot create a profile for clinic-B patient B1');
reset role;

-- ---------------------------------------------------------------------------
-- Own clinic still works (positive controls)
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select lives_ok($$ insert into public.lab_reports (org_id, patient_id, report_type, data) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'basic_panel', '{"fictional":true}') $$,
  'physician A files a lab report for own-clinic patient A1');
select lives_ok($$ insert into public.consents (org_id, patient_id, consent_type, granted) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a6002', 'data_sharing', true) $$,
  'physician A records a consent for own-clinic patient A2');
select lives_ok($$ insert into public.patient_profiles (org_id, patient_id, data) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a6002', '{}') $$,
  'physician A creates a profile for own-clinic patient A2');
with u as (update public.lab_reports set data = '{"result":"fictional-v2"}' where id = '00000000-0000-0000-0000-0000000a3001' returning 1)
  insert into tc040_seen select 'phys-a-update-own-report', count(*) from u;
-- same-value write of patient_id / org_id (what an upsert sends) is fine
with u as (update public.lab_reports set patient_id = '00000000-0000-0000-0000-0000000a1001', org_id = '00000000-0000-0000-0000-00000000000a'
            where id = '00000000-0000-0000-0000-0000000a3001' returning 1)
  insert into tc040_seen select 'phys-a-same-value', count(*) from u;
with u as (update public.patient_profiles set data = '{"note":"fictional-v2"}' where id = '00000000-0000-0000-0000-0000000a2001' returning 1)
  insert into tc040_seen select 'phys-a-update-own-profile', count(*) from u;
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2');
with u as (update public.consents set granted = false where id = '00000000-0000-0000-0000-0000000a4001' returning 1)
  insert into tc040_seen select 'coord-a-update-own-consent', count(*) from u;
reset role;
select is((select n from tc040_seen where who = 'phys-a-update-own-report'), 1, 'physician A updates an own-clinic lab report');
select is((select n from tc040_seen where who = 'phys-a-same-value'), 1, 'a same-value patient_id/org_id write (upsert shape) still works');
select is((select n from tc040_seen where who = 'phys-a-update-own-profile'), 1, 'physician A updates an own-clinic profile');
select is((select n from tc040_seen where who = 'coord-a-update-own-consent'), 1, 'care coordinator A updates an own-clinic consent');

-- ---------------------------------------------------------------------------
-- Re-pointing (card item 2): patient_id is immutable for clients, even to a
-- patient of the same clinic, and an existing row can't be moved to clinic A.
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2');
select throws_ok($$ update public.lab_reports set patient_id = '00000000-0000-0000-0000-0000000a1001' where id = '00000000-0000-0000-0000-0000000b3001' $$,
  '42501', null, 'physician B cannot re-point a clinic-B lab report at clinic-A patient A1');
select throws_ok($$ update public.lab_reports set patient_id = '00000000-0000-0000-0000-0000000a1001',
    pdf_path = '00000000-0000-0000-0000-0000000a1001/46a00000-0000-4000-8000-000000000001.pdf'
  where id = '00000000-0000-0000-0000-0000000b3001' $$,
  '42501', null, 'M1: physician B cannot re-point a clinic-B report at A1''s PDF');
select throws_ok($$ update public.consents set patient_id = '00000000-0000-0000-0000-0000000a1001' where id = '00000000-0000-0000-0000-0000000b4001' $$,
  '42501', null, 'physician B cannot re-point a clinic-B consent at clinic-A patient A1');
select throws_ok($$ update public.patient_profiles set patient_id = '00000000-0000-0000-0000-0000000a1001' where id = '00000000-0000-0000-0000-0000000b2001' $$,
  '42501', null, 'physician B cannot re-point a clinic-B profile at clinic-A patient A1');
select throws_ok($$ update public.lab_reports set org_id = '00000000-0000-0000-0000-00000000000a' where id = '00000000-0000-0000-0000-0000000b3001' $$,
  '42501', null, 'physician B cannot move a clinic-B lab report into clinic A');
select throws_ok($$ update public.consents set org_id = '00000000-0000-0000-0000-00000000000a' where id = '00000000-0000-0000-0000-0000000b4001' $$,
  '42501', null, 'physician B cannot move a clinic-B consent into clinic A');
select throws_ok($$ update public.patient_profiles set org_id = '00000000-0000-0000-0000-00000000000a' where id = '00000000-0000-0000-0000-0000000b2001' $$,
  '42501', null, 'physician B cannot move a clinic-B profile into clinic A');
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select throws_ok($$ update public.lab_reports set patient_id = '00000000-0000-0000-0000-0000000a6002' where id = '00000000-0000-0000-0000-0000000a3001' $$,
  '42501', null, 'patient_id is immutable: physician A cannot move a report from A1 to same-clinic A2');
select throws_ok($$ update public.consents set patient_id = '00000000-0000-0000-0000-0000000a6002' where id = '00000000-0000-0000-0000-0000000a4001' $$,
  '42501', null, 'patient_id is immutable: physician A cannot move a consent from A1 to same-clinic A2');
select throws_ok($$ update public.patient_profiles set patient_id = '00000000-0000-0000-0000-0000000a6002' where id = '00000000-0000-0000-0000-0000000a2001' $$,
  '42501', null, 'patient_id is immutable: physician A cannot move a profile from A1 to same-clinic A2');
reset role;
select is((select patient_id::text || '/' || org_id::text from public.lab_reports where id = '00000000-0000-0000-0000-0000000b3001'),
  '00000000-0000-0000-0000-0000000b1001/00000000-0000-0000-0000-00000000000b', 'clinic-B report still about B1 in clinic B');
select is((select patient_id::text from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  '00000000-0000-0000-0000-0000000a1001', 'clinic-A report still about A1');

-- org_id immutability holds on its own, not only through the org_id WITH
-- CHECK / SELECT visibility of the new row: with permissive probe UPDATE and
-- SELECT policies (this transaction only), a client still can't change it.
create policy tc040_probe_lr_select_all on public.lab_reports for select to authenticated using (true);
create policy tc040_probe_c_select_all on public.consents for select to authenticated using (true);
create policy tc040_probe_pp_select_all on public.patient_profiles for select to authenticated using (true);
create policy tc040_probe_lr_update_all on public.lab_reports for update to authenticated using (true) with check (true);
create policy tc040_probe_c_update_all on public.consents for update to authenticated using (true) with check (true);
create policy tc040_probe_pp_update_all on public.patient_profiles for update to authenticated using (true) with check (true);
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2');
select throws_ok($$ update public.lab_reports set org_id = '00000000-0000-0000-0000-00000000000a' where id = '00000000-0000-0000-0000-0000000b3001' $$,
  '42501', null, 'immutable on its own: org_id of a lab report can''t change even under a permissive policy');
select throws_ok($$ update public.consents set org_id = '00000000-0000-0000-0000-00000000000a' where id = '00000000-0000-0000-0000-0000000b4001' $$,
  '42501', null, 'immutable on its own: org_id of a consent can''t change even under a permissive policy');
select throws_ok($$ update public.patient_profiles set org_id = '00000000-0000-0000-0000-00000000000a' where id = '00000000-0000-0000-0000-0000000b2001' $$,
  '42501', null, 'immutable on its own: org_id of a profile can''t change even under a permissive policy');
reset role;
drop policy tc040_probe_lr_update_all on public.lab_reports;
drop policy tc040_probe_c_update_all on public.consents;
drop policy tc040_probe_pp_update_all on public.patient_profiles;
drop policy tc040_probe_lr_select_all on public.lab_reports;
drop policy tc040_probe_c_select_all on public.consents;
drop policy tc040_probe_pp_select_all on public.patient_profiles;

-- Server side is not blocked (a reviewed clinic-transfer path, TC-034 item
-- 69, stays possible): service_role can still correct patient_id / org_id.
select set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
set local role service_role;
select lives_ok($$ update public.consents set org_id = '00000000-0000-0000-0000-00000000000a', patient_id = '00000000-0000-0000-0000-0000000a1001'
  where id = '00000000-0000-0000-0000-00000046b401' $$,
  'service_role can still move a row (server-side correction)');
reset role;
update public.consents set org_id = '00000000-0000-0000-0000-00000000000b' where id = '00000000-0000-0000-0000-00000046b401';
select set_config('request.jwt.claims', '', true);

-- ---------------------------------------------------------------------------
-- Rows already pointing at another clinic's patient (left by M1 before this
-- fix) can't be edited by the clinic that filed them.
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2');
select throws_ok($$ update public.lab_reports set data = '{"x":1}' where id = '00000000-0000-0000-0000-00000046b301' $$,
  '42501', null, 'physician B cannot edit a clinic-B lab report that names clinic-A patient A1');
select throws_ok($$ update public.consents set granted = false where id = '00000000-0000-0000-0000-00000046b401' $$,
  '42501', null, 'physician B cannot edit a clinic-B consent that names clinic-A patient A1');
select throws_ok($$ update public.patient_profiles set data = '{"x":1}' where id = '00000000-0000-0000-0000-00000046b201' $$,
  '42501', null, 'physician B cannot edit a clinic-B profile that names clinic-A patient A1');
reset role;

-- ---------------------------------------------------------------------------
-- The clinic predicate is explicit, not just patients RLS: with a permissive
-- probe SELECT policy on patients (every clinic's patients visible), staff
-- still can't write about another clinic's patient.
-- ---------------------------------------------------------------------------
create policy tc040_probe_patients_all on public.patients for select to authenticated using (true);
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2');
select ok((select count(*) from public.patients where id = '00000000-0000-0000-0000-0000000a1001') = 1,
  'probe: widened patients policy shows physician B clinic-A patient A1');
select throws_ok($$ insert into public.lab_reports (org_id, patient_id, report_type, data) values
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000a1001', 'basic_panel', '{}') $$,
  '42501', null, 'explicit predicate: lab report insert about A1 refused even when A1 is visible');
select throws_ok($$ insert into public.consents (org_id, patient_id, consent_type, granted) values
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000a1001', 'data_sharing', true) $$,
  '42501', null, 'explicit predicate: consent insert about A1 refused even when A1 is visible');
select throws_ok($$ insert into public.patient_profiles (org_id, patient_id, data) values
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000a1001', '{}') $$,
  '42501', null, 'explicit predicate: profile insert about A1 refused even when A1 is visible');
select throws_ok($$ update public.lab_reports set data = '{"x":2}' where id = '00000000-0000-0000-0000-00000046b301' $$,
  '42501', null, 'explicit predicate: lab report update of a row naming A1 refused even when A1 is visible');
select throws_ok($$ update public.consents set granted = false where id = '00000000-0000-0000-0000-00000046b401' $$,
  '42501', null, 'explicit predicate: consent update of a row naming A1 refused even when A1 is visible');
select throws_ok($$ update public.patient_profiles set data = '{"x":2}' where id = '00000000-0000-0000-0000-00000046b201' $$,
  '42501', null, 'explicit predicate: profile update of a row naming A1 refused even when A1 is visible');
reset role;
drop policy tc040_probe_patients_all on public.patients;
select set_config('request.jwt.claims', '', true);

-- ---------------------------------------------------------------------------
-- Patients' own write paths are unaffected by the immutability trigger.
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', '', true);
insert into public.consent_documents (consent_type, version, document, title, summary, body, required, is_placeholder, published_at)
values ('health_data', 'synthetic-fixture', 'synthetic_health_data_fixture', 'Synthetic fixture',
        'SYNTHETIC FIXTURE - not a legally approved document',
        'SYNTHETIC FIXTURE - not a legally approved document. Not for patient use.',
        false, false, now());
insert into public.consents (org_id, patient_id, consent_type, document, version, granted)
values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001',
        'health_data', 'synthetic_health_data_fixture', 'synthetic-fixture', true);
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1');
with u as (update public.consents set granted = false where id = '00000000-0000-0000-0000-00000046a401' returning 1)
  insert into tc040_seen select 'a1-update-own-consent', count(*) from u;
select lives_ok($$ insert into public.lab_reports (org_id, patient_id, report_type, data) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'patient_upload', '{}') $$,
  'patient A1 can still file their own lab report');
reset role;
select is((select n from tc040_seen where who = 'a1-update-own-consent'), 1, 'patient A1 can still update their own consent');

-- ---------------------------------------------------------------------------
-- lab_results (biomarker rows, card item 3): no client write path at all.
-- ---------------------------------------------------------------------------
select ok(not has_table_privilege('authenticated', 'public.lab_results', 'INSERT'), 'authenticated has no INSERT on lab_results');
select ok(not has_table_privilege('authenticated', 'public.lab_results', 'UPDATE'), 'authenticated has no UPDATE on lab_results');
select ok(not has_table_privilege('anon', 'public.lab_results', 'INSERT') and not has_table_privilege('anon', 'public.lab_results', 'UPDATE'),
  'anon has no INSERT/UPDATE on lab_results');
select is((select count(*)::int from pg_policies where schemaname = 'public' and tablename = 'lab_results' and cmd in ('INSERT', 'UPDATE', 'ALL')),
  0, 'lab_results has no INSERT/UPDATE policy');
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2');
select throws_ok($$ insert into public.lab_results (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value) values
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-0000000b3001', 'glucose', 'Glucose', 90) $$,
  '42501', null, 'physician B cannot write a biomarker row about A1');
reset role;

-- ---------------------------------------------------------------------------
-- Internal record-linking helpers (audit finding): not callable by clients.
-- ---------------------------------------------------------------------------
select is(
  (select array_agg(f order by f) from unnest(array[
     'public._bind_patient_record(uuid,uuid,text,text)', 'public._enqueue_link_notices(uuid,uuid,text,text)',
     'public._patient_link_clear_attempts(uuid)', 'public._patient_link_register_wrong(uuid,integer,integer)',
     'public._patient_link_locked(uuid)', 'public._clinic_code_breaker_bump()', 'public._clinic_code_breaker_tripped()']) f
    where has_function_privilege('authenticated', f, 'EXECUTE') or has_function_privilege('anon', f, 'EXECUTE')),
  null, 'no internal record-linking helper is executable by anon or authenticated');
select ok(has_function_privilege('service_role', 'public._bind_patient_record(uuid,uuid,text,text)', 'EXECUTE'),
  'service_role keeps EXECUTE on _bind_patient_record');
select is(
  (select array_agg(p.oid::regprocedure::text order by 1) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef and p.proname like '\_%'
      and (has_function_privilege('authenticated', p.oid, 'EXECUTE') or has_function_privilege('anon', p.oid, 'EXECUTE'))),
  null, 'no underscore-internal SECURITY DEFINER function in public is executable by anon or authenticated');
select tests.authenticate_as('00000000-0000-0000-0000-000000046c01', 'aal1');
select throws_ok($$ select public._bind_patient_record('00000000-0000-0000-0000-000000046c01', '00000000-0000-0000-0000-00000000000b', 'th_tc040_direct', 'clinic_code') $$,
  '42501', null, 'a signed-in user cannot bind themselves into another clinic via _bind_patient_record');
select throws_ok($$ select public._patient_link_clear_attempts('00000000-0000-0000-0000-000000046c01') $$,
  '42501', null, 'a signed-in user cannot clear their own code-guess lockout');
reset role;
select tests.authenticate_as_anon();
select throws_ok($$ select public._enqueue_link_notices('00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000000000a', 'th_tc040', 'linked') $$,
  '42501', null, 'anon cannot enqueue link notices');
reset role;
select is((select count(*)::int from public.patient_record_links where telehealth_patient_id = 'th_tc040_direct'), 0, 'no link row was created');
select is((select count(*)::int from public.patients where id = '00000000-0000-0000-0000-000000046c01'), 0, 'the new account was not placed in any clinic');

select * from finish();
rollback;
