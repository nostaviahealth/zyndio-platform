-- TC-040 item 6 + 7 (Clara, PR #33 r2 L1 + L2): the clinic-staff read rule on
-- lab-report files
--   * finds the folder's patient through patients_pkey (uuid compare), not a
--     scan of the whole clinic (L1: ~189 ms -> ~1 ms per signed link at 10k
--     patients per clinic; timing check: scripts/bench-lab-reports-sign.sh,
--     output in docs/perf/tc-040/);
--   * refuses a non-uuid / non-canonical first path segment WITHOUT raising,
--     so one odd object can never break listing or signing for real users;
--   * keeps its own clinic predicate on the folder's patient even if patients
--     RLS is ever widened (L2: makes that predicate non-redundant in test);
--   * matches the exact folder segment for staff too, never a name prefix
--     (L2: staff-side sibling-prefix fixture).
-- Same model as 744: storage-api reads/lists/signs as the caller under this
-- RLS, so SET ROLE + claims (tests.authenticate_as) is what the API enforces.
-- Probes (widened policies, dropped CHECK) live only in this rolled-back
-- transaction. Fictional data only.
begin;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);

-- Fixture actors: physician A a0002, coordinator A a0003 (clinic A), patient
-- A1 a1001 (clinic A), patient B1 b1001 (clinic B), physician B b0001.
insert into storage.objects (bucket_id, name) values
  ('lab-reports', '00000000-0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000001.pdf'), -- A1, filed by clinic A
  ('lab-reports', '00000000-0000-0000-0000-0000000b1001/40b00000-0000-4000-8000-000000000001.pdf'); -- B1, filed by clinic B
insert into public.lab_reports (id, org_id, patient_id, report_type, data, pdf_path) values
  ('00000000-0000-0000-0000-00000040a301', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'patient_upload', '{}',
   '00000000-0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000001.pdf'),
  ('00000000-0000-0000-0000-00000040b301', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000b1001', 'patient_upload', '{}',
   '00000000-0000-0000-0000-0000000b1001/40b00000-0000-4000-8000-000000000001.pdf');

create or replace function pg_temp.visible() returns text[] language sql as $$
  select coalesce(array_agg(name order by name), '{}') from storage.objects
   where bucket_id = 'lab-reports' and name like '%40_00000-0000-4000-8000-%' $$;
-- what storage-api runs (as the caller) before it mints a signed URL
create or replace function pg_temp.sign(p_name text) returns int language sql as $$
  select count(*)::int from storage.objects where bucket_id = 'lab-reports' and name = p_name $$;
-- TC-040 (#34 M1): functions postgres creates no longer get PUBLIC EXECUTE by
-- default, so test-only helpers called after a role switch are granted explicitly.
grant execute on function pg_temp.visible(), pg_temp.sign(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Structure: uuid compare, guarded by the canonical-uuid regex
-- ---------------------------------------------------------------------------
select ok((select pg_get_expr(polqual, polrelid) from pg_policy where polname = 'lab_reports_objects_staff_select')
          ~ 'split_part\(objects\.name, ''/''::text, 1\)\)::uuid',
  'staff read rule compares the folder to patients.id as uuid (not p.id::text)');
select ok((select pg_get_expr(polqual, polrelid) from pg_policy where polname = 'lab_reports_objects_staff_select')
          !~ 'p\.id\)::text',
  'staff read rule no longer casts patients.id to text');

-- ---------------------------------------------------------------------------
-- Positive controls
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select is(pg_temp.sign('00000000-0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000001.pdf'), 1,
  'physician A can still sign a clinic-A patient''s filed report');
select is(pg_temp.sign('00000000-0000-0000-0000-0000000b1001/40b00000-0000-4000-8000-000000000001.pdf'), 0,
  'physician A cannot sign clinic B''s file');
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2');
select is(pg_temp.sign('00000000-0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000001.pdf'), 1,
  'care coordinator A can still sign a clinic-A patient''s filed report');
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2');
select is(pg_temp.sign('00000000-0000-0000-0000-0000000b1001/40b00000-0000-4000-8000-000000000001.pdf'), 1,
  'physician B can still sign a clinic-B patient''s filed report');
select is(pg_temp.sign('00000000-0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000001.pdf'), 0,
  'physician B cannot sign clinic A''s file');
reset role;
select set_config('request.jwt.claims', '', true);

-- ---------------------------------------------------------------------------
-- Non-uuid / non-canonical first segments: refused, and never an error.
-- Each is filed by a clinic-A row about A1 so the patient lookup really runs
-- for it (the pdf_path CHECK would stop such rows today; it is dropped only
-- inside this transaction to model a legacy or service-written row).
-- ---------------------------------------------------------------------------
alter table public.lab_reports drop constraint lab_reports_pdf_path_own_folder;
insert into storage.objects (bucket_id, name) values
  ('lab-reports', 'not-a-uuid/40a00000-0000-4000-8000-000000000011.pdf'),
  ('lab-reports', '40a00000-0000-4000-8000-000000000012.pdf'),                                       -- no folder at all
  ('lab-reports', '00000000-0000-0000-0000-0000000A1001/40a00000-0000-4000-8000-000000000013.pdf'), -- upper case
  ('lab-reports', '{00000000-0000-0000-0000-0000000a1001}/40a00000-0000-4000-8000-000000000014.pdf'), -- brace form
  ('lab-reports', '000000000000000000000000000a1001/40a00000-0000-4000-8000-000000000015.pdf'),     -- no hyphens
  ('lab-reports', '00000000-0000-0000-0000-0000000a10010/40a00000-0000-4000-8000-000000000016.pdf'), -- sibling folder (prefix)
  ('lab-reports', '00000000-0000-0000-0000-0000000a1001.40a00000-0000-4000-8000-000000000017.pdf'), -- root name, same prefix
  ('lab-reports', 'x00000000-0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000018.pdf'), -- L1 (#34 review): junk before the uuid (start anchor)
  ('lab-reports', '000000000-0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000019.pdf'), -- L1 (#34 review): an extra leading hex digit before the uuid (start anchor)
  ('lab-reports', '00000000.0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000020.pdf'), -- L1 (#34 review): '.' in place of hyphen 1
  ('lab-reports', '00000000-0000.0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000021.pdf'), -- L1 (#34 review): '.' in place of hyphen 2
  ('lab-reports', '00000000-0000-0000.0000-0000000a1001/40a00000-0000-4000-8000-000000000022.pdf'), -- L1 (#34 review): '.' in place of hyphen 3
  ('lab-reports', '00000000-0000-0000-0000.0000000a1001/40a00000-0000-4000-8000-000000000023.pdf'), -- L1 (#34 review): '.' in place of hyphen 4
  ('lab-reports', '00000000_0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000024.pdf'), -- L1 (#34 review): '_' in place of hyphen 1
  ('lab-reports', '00000000_0000_0000_0000_0000000a1001/40a00000-0000-4000-8000-000000000025.pdf'); -- L1 (#34 review): '_' in place of every hyphen
insert into public.lab_reports (org_id, patient_id, report_type, data, pdf_path)
select '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'legacy', '{}', n
  from unnest(array[
    'not-a-uuid/40a00000-0000-4000-8000-000000000011.pdf',
    '40a00000-0000-4000-8000-000000000012.pdf',
    '00000000-0000-0000-0000-0000000A1001/40a00000-0000-4000-8000-000000000013.pdf',
    '{00000000-0000-0000-0000-0000000a1001}/40a00000-0000-4000-8000-000000000014.pdf',
    '000000000000000000000000000a1001/40a00000-0000-4000-8000-000000000015.pdf',
    '00000000-0000-0000-0000-0000000a10010/40a00000-0000-4000-8000-000000000016.pdf',
    '00000000-0000-0000-0000-0000000a1001.40a00000-0000-4000-8000-000000000017.pdf',
    'x00000000-0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000018.pdf',
    '000000000-0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000019.pdf',
    '00000000.0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000020.pdf',
    '00000000-0000.0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000021.pdf',
    '00000000-0000-0000.0000-0000000a1001/40a00000-0000-4000-8000-000000000022.pdf',
    '00000000-0000-0000-0000.0000000a1001/40a00000-0000-4000-8000-000000000023.pdf',
    '00000000_0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000024.pdf',
    '00000000_0000_0000_0000_0000000a1001/40a00000-0000-4000-8000-000000000025.pdf']) n;

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select lives_ok($$ select pg_temp.visible() $$,
  'physician A lists the bucket without an error even with non-uuid first segments present');
select lives_ok($$ select count(*) from storage.objects where bucket_id = 'lab-reports' $$,
  'physician A plain bucket listing does not error on non-uuid first segments');
select lives_ok($$ select pg_temp.sign('not-a-uuid/40a00000-0000-4000-8000-000000000011.pdf') $$,
  'signing a non-uuid path does not raise (refused quietly)');
select is(pg_temp.visible(),
  array['00000000-0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000001.pdf'],
  'physician A still sees exactly the one real clinic-A file (no non-canonical name is served)');
select is(pg_temp.sign('not-a-uuid/40a00000-0000-4000-8000-000000000011.pdf'), 0, 'non-uuid folder: refused');
select is(pg_temp.sign('40a00000-0000-4000-8000-000000000012.pdf'), 0, 'no folder: refused');
select is(pg_temp.sign('00000000-0000-0000-0000-0000000A1001/40a00000-0000-4000-8000-000000000013.pdf'), 0,
  'upper-case uuid folder: refused (only the canonical lowercase folder is the patient''s)');
select is(pg_temp.sign('{00000000-0000-0000-0000-0000000a1001}/40a00000-0000-4000-8000-000000000014.pdf'), 0,
  'brace-form uuid folder: refused');
select is(pg_temp.sign('000000000000000000000000000a1001/40a00000-0000-4000-8000-000000000015.pdf'), 0,
  'hyphen-less uuid folder: refused');
-- L2: staff-side sibling-prefix fixture
select is(pg_temp.sign('00000000-0000-0000-0000-0000000a10010/40a00000-0000-4000-8000-000000000016.pdf'), 0,
  'staff sibling-prefix: a folder that only STARTS with A1''s id is not A1''s (physician A refused)');
select is(pg_temp.sign('00000000-0000-0000-0000-0000000a1001.40a00000-0000-4000-8000-000000000017.pdf'), 0,
  'staff sibling-prefix: a root-level name that only starts with A1''s id is refused');
-- L1 (#34 review): the regex must be anchored at the start and use literal
-- hyphens. Without '^' or with '.' for '-', these folders pass the guard and the
-- ::uuid cast raises (lives_ok fails); with the correct guard they are refused.
select lives_ok($$ select pg_temp.sign('x00000000-0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000018.pdf') $$,
  'L1: signing a folder with junk before the uuid (start anchor) does not raise');
select is(pg_temp.sign('x00000000-0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000018.pdf'), 0,
  'L1: folder with junk before the uuid (start anchor): refused');
select lives_ok($$ select pg_temp.sign('000000000-0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000019.pdf') $$,
  'L1: signing a folder with an extra leading hex digit before the uuid (start anchor) does not raise');
select is(pg_temp.sign('000000000-0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000019.pdf'), 0,
  'L1: folder with an extra leading hex digit before the uuid (start anchor): refused');
select lives_ok($$ select pg_temp.sign('00000000.0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000020.pdf') $$,
  'L1: signing a folder with ''.'' in place of hyphen 1 does not raise');
select is(pg_temp.sign('00000000.0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000020.pdf'), 0,
  'L1: folder with ''.'' in place of hyphen 1: refused');
select lives_ok($$ select pg_temp.sign('00000000-0000.0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000021.pdf') $$,
  'L1: signing a folder with ''.'' in place of hyphen 2 does not raise');
select is(pg_temp.sign('00000000-0000.0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000021.pdf'), 0,
  'L1: folder with ''.'' in place of hyphen 2: refused');
select lives_ok($$ select pg_temp.sign('00000000-0000-0000.0000-0000000a1001/40a00000-0000-4000-8000-000000000022.pdf') $$,
  'L1: signing a folder with ''.'' in place of hyphen 3 does not raise');
select is(pg_temp.sign('00000000-0000-0000.0000-0000000a1001/40a00000-0000-4000-8000-000000000022.pdf'), 0,
  'L1: folder with ''.'' in place of hyphen 3: refused');
select lives_ok($$ select pg_temp.sign('00000000-0000-0000-0000.0000000a1001/40a00000-0000-4000-8000-000000000023.pdf') $$,
  'L1: signing a folder with ''.'' in place of hyphen 4 does not raise');
select is(pg_temp.sign('00000000-0000-0000-0000.0000000a1001/40a00000-0000-4000-8000-000000000023.pdf'), 0,
  'L1: folder with ''.'' in place of hyphen 4: refused');
select lives_ok($$ select pg_temp.sign('00000000_0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000024.pdf') $$,
  'L1: signing a folder with ''_'' in place of hyphen 1 does not raise');
select is(pg_temp.sign('00000000_0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000024.pdf'), 0,
  'L1: folder with ''_'' in place of hyphen 1: refused');
select lives_ok($$ select pg_temp.sign('00000000_0000_0000_0000_0000000a1001/40a00000-0000-4000-8000-000000000025.pdf') $$,
  'L1: signing a folder with ''_'' in place of every hyphen does not raise');
select is(pg_temp.sign('00000000_0000_0000_0000_0000000a1001/40a00000-0000-4000-8000-000000000025.pdf'), 0,
  'L1: folder with ''_'' in place of every hyphen: refused');
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2');
select is(pg_temp.visible(),
  array['00000000-0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000001.pdf'],
  'care coordinator A: same, no sibling-prefix or non-canonical name is served');
reset role;
select set_config('request.jwt.claims', '', true);

-- ---------------------------------------------------------------------------
-- L2: the clinic predicate on the folder's patient is not just patients RLS.
-- Probe (this transaction only): a permissive patients SELECT policy that
-- shows every clinic's patients to every signed-in user. A clinic-A row that
-- files clinic-B patient B1's object (forged; pdf_path CHECK already dropped
-- above) must still not open B1's file to physician A.
-- ---------------------------------------------------------------------------
insert into storage.objects (bucket_id, name) values
  ('lab-reports', '00000000-0000-0000-0000-0000000b1001/40b00000-0000-4000-8000-000000000002.pdf');
insert into public.lab_reports (org_id, patient_id, report_type, data, pdf_path) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'forged', '{}',
   '00000000-0000-0000-0000-0000000b1001/40b00000-0000-4000-8000-000000000002.pdf');
create policy tc040_probe_patients_all on public.patients for select to authenticated using (true);
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select ok((select count(*) from public.patients where id = '00000000-0000-0000-0000-0000000b1001') = 1,
  'probe: widened patients policy shows physician A clinic-B patient B1');
select is(pg_temp.sign('00000000-0000-0000-0000-0000000b1001/40b00000-0000-4000-8000-000000000002.pdf'), 0,
  'explicit clinic predicate: physician A cannot open B1''s file via a clinic-A row even when B1 is visible');
select is(pg_temp.sign('00000000-0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000001.pdf'), 1,
  'probe positive control: physician A still signs the real clinic-A file');
reset role;
drop policy tc040_probe_patients_all on public.patients;
select set_config('request.jwt.claims', '', true);

-- ---------------------------------------------------------------------------
-- L1 plan check at Henry's scale: 10,000 fictional patients in clinic A (and
-- 10,000 in clinic B). Signing one file must look the folder's patient up
-- through patients_pkey, not scan the clinic (patients_org_id_idx / seq scan).
-- Timing itself is measured by scripts/bench-lab-reports-sign.sh (a CI timer
-- would be flaky); the plan shape is what makes it fast and is deterministic.
-- ---------------------------------------------------------------------------
insert into auth.users (id, email, email_confirmed_at, aud, role)
select ('0000c040-0000-4000-9000-' || lpad(to_hex(g), 12, '0'))::uuid,
       'tc040-scale-' || g || '@example.test', now(), 'authenticated', 'authenticated'
  from generate_series(1, 20000) g;
insert into public.patients (id, org_id, display_name, mrn)
select ('0000c040-0000-4000-9000-' || lpad(to_hex(g), 12, '0'))::uuid,
       case when g % 2 = 0 then '00000000-0000-0000-0000-00000000000a'::uuid else '00000000-0000-0000-0000-00000000000b'::uuid end,
       'Fictional Scale Patient ' || g, 'TC040-' || g
  from generate_series(1, 20000) g;
analyze public.patients;
analyze public.lab_reports;
analyze storage.objects;
select ok((select count(*) from public.patients where org_id = '00000000-0000-0000-0000-00000000000a') >= 10000,
  'scale fixture: clinic A has at least 10,000 patients');

create or replace function pg_temp.sign_plan(p_name text) returns text language plpgsql as $$
declare v_line text; v_plan text := '';
begin
  for v_line in execute format(
    'explain (costs off) select name from storage.objects where bucket_id = %L and name = %L', 'lab-reports', p_name)
  loop v_plan := v_plan || v_line || E'\n'; end loop;
  return v_plan;
end $$;
grant execute on function pg_temp.sign_plan(text) to authenticated;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select diag(pg_temp.sign_plan('00000000-0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000001.pdf'));
select ok(pg_temp.sign_plan('00000000-0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000001.pdf') ~ 'Index Scan using patients_pkey on patients',
  'sign at 10k patients/clinic: folder patient found via patients_pkey');
select ok(pg_temp.sign_plan('00000000-0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000001.pdf') !~ 'patients_org_id_idx|Seq Scan on patients',
  'sign at 10k patients/clinic: no scan of the clinic''s patients');
select is(pg_temp.sign('00000000-0000-0000-0000-0000000a1001/40a00000-0000-4000-8000-000000000001.pdf'), 1,
  'sign at 10k patients/clinic: still allowed for the own-clinic file');
reset role;

select * from finish();
rollback;
