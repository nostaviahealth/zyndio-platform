-- TC-036: the `lab-reports` storage bucket is private and storage.objects RLS
-- lets each patient reach ONLY their own folder (<patient_id>/<uuid>.<ext>),
-- lets own-clinic physicians / care coordinators READ only files that a
-- lab_reports row they can already read points at, and gives anon, read_only,
-- org_admin, other patients (same clinic or not) and other clinics nothing,
-- even through a lab_reports row filed under the wrong clinic (M1).
-- Also: lab_reports.pdf_path stays inside the report's own patient folder,
-- and saved links are converted to paths (bad ones quarantined).
--
-- storage-api runs every object read/list/upload/delete/sign as the caller's
-- role with the caller's JWT claims under this RLS, so SET ROLE + claims here
-- (tests.authenticate_as) exercises exactly what the API enforces. A signed
-- URL is only minted after an RLS-checked SELECT of the object, so "can't
-- SELECT" also means "can't get a signed link". Fictional data only.
begin;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);
-- Newer storage schemas (storage-api >= ~1.8x, as in CI's supabase CLI) add a
-- statement trigger storage.protect_delete that rejects DELETE unless
-- storage.allow_delete_query = 'true'. storage-api sets that flag itself on its
-- delete path, so we set it too; RLS is still what decides which rows go.
-- On older storage schemas without the trigger this is a no-op.
select set_config('storage.allow_delete_query', 'true', true);

-- Actors (global fixtures): patient A1 a1001 (clinic A), patient B1 b1001
-- (clinic B), physician A a0002, coordinator A a0003, read_only A a0004,
-- org_admin A a0001, physician B b0001. Same-clinic patient A2 a6002 gets its
-- patients row + active link here.
insert into public.patients (id, org_id, display_name, mrn) values
  ('00000000-0000-0000-0000-0000000a6002', '00000000-0000-0000-0000-00000000000a', 'Fictional Patient A2', 'MRN-A2');
insert into public.patient_record_links (app_user_id, org_id, telehealth_patient_id, status, linked_at, proof_method) values
  ('00000000-0000-0000-0000-0000000a6002', '00000000-0000-0000-0000-00000000000a',
   'clinic:00000000-0000-0000-0000-0000000a6002', 'active', now(), 'clinic_provisioned');

-- Objects as storage-api would have written them (service side).
insert into storage.objects (bucket_id, name) values
  ('lab-reports', '00000000-0000-0000-0000-0000000a1001/36a00000-0000-4000-8000-000000000001.pdf'), -- A1, filed
  ('lab-reports', '00000000-0000-0000-0000-0000000a1001/36a00000-0000-4000-8000-000000000002.pdf'), -- A1, unfiled (orphan)
  ('lab-reports', '00000000-0000-0000-0000-0000000a6002/36a00000-0000-4000-8000-000000000003.pdf'), -- A2, filed
  ('lab-reports', '00000000-0000-0000-0000-0000000a6002/36a00000-0000-4000-8000-000000000004.pdf'), -- A2, unfiled
  ('lab-reports', '00000000-0000-0000-0000-0000000b1001/36b00000-0000-4000-8000-000000000001.pdf'); -- B1, filed

insert into public.lab_reports (id, org_id, patient_id, report_type, data, pdf_path) values
  ('00000000-0000-0000-0000-00000036a301', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'patient_upload', '{}',
   '00000000-0000-0000-0000-0000000a1001/36a00000-0000-4000-8000-000000000001.pdf'),
  ('00000000-0000-0000-0000-00000036a302', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a6002', 'patient_upload', '{}',
   '00000000-0000-0000-0000-0000000a6002/36a00000-0000-4000-8000-000000000003.pdf'),
  ('00000000-0000-0000-0000-00000036b301', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000b1001', 'patient_upload', '{}',
   '00000000-0000-0000-0000-0000000b1001/36b00000-0000-4000-8000-000000000001.pdf');

create temp table tc036_seen (who text, n int);
grant all on tc036_seen to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Bucket + policy structure
-- ---------------------------------------------------------------------------
select is((select count(*)::int from storage.buckets where id = 'lab-reports'), 1, 'lab-reports bucket exists');
-- storage-api adds buckets.public (default false); a DB without storage-api has
-- no such column and therefore no public mode. Read it via to_jsonb so the test
-- holds on both, and fails if the bucket is public.
select is((select coalesce((to_jsonb(b) ->> 'public')::boolean, false) from storage.buckets b where id = 'lab-reports'),
          false, 'lab-reports bucket is NOT public');
select is(
  (select array_agg(policyname::text order by policyname) from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and (coalesce(qual, '') || coalesce(with_check, '')) like '%lab-reports%'),
  array['lab_reports_objects_self_delete_unfiled', 'lab_reports_objects_self_insert',
        'lab_reports_objects_self_select', 'lab_reports_objects_staff_select'],
  'exactly the four reviewed storage.objects policies cover lab-reports (no update policy for anyone)');
select is(
  (select count(*)::int from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname like 'lab_reports_objects_%' and roles <> '{authenticated}'::name[]),
  0, 'every lab-reports policy is TO authenticated only (none for anon/public)');

-- ---------------------------------------------------------------------------
-- anon (explicit anon claim, and a raw request with no claims at all)
-- ---------------------------------------------------------------------------
select tests.authenticate_as_anon();
select is((select count(*)::int from storage.objects where bucket_id = 'lab-reports'), 0, 'anon reads/lists nothing in lab-reports');
select throws_ok($$ insert into storage.objects (bucket_id, name) values ('lab-reports', '00000000-0000-0000-0000-0000000a1001/36a00000-0000-4000-8000-0000000000aa.pdf') $$,
  '42501', null, 'anon cannot upload into lab-reports');
with d as (delete from storage.objects where bucket_id = 'lab-reports' returning 1) insert into tc036_seen select 'anon-delete', count(*) from d;
with u as (update storage.objects set metadata = '{}' where bucket_id = 'lab-reports' returning 1) insert into tc036_seen select 'anon-update', count(*) from u;
select tests.clear_authentication();
select is((select count(*)::int from storage.objects where bucket_id = 'lab-reports'), 0, 'no-claims request reads nothing in lab-reports');
reset role;
select is((select array_agg(n) from tc036_seen where who like 'anon-%'), array[0, 0], 'anon deletes and updates nothing');
select is((select count(*)::int from storage.objects where bucket_id = 'lab-reports'), 5, 'all five objects still exist after anon attempts');

-- ---------------------------------------------------------------------------
-- Patient A1 (clinic A)
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1');
select is((select array_agg(name order by name) from storage.objects where bucket_id = 'lab-reports'),
  array['00000000-0000-0000-0000-0000000a1001/36a00000-0000-4000-8000-000000000001.pdf',
        '00000000-0000-0000-0000-0000000a1001/36a00000-0000-4000-8000-000000000002.pdf'],
  'patient A1 lists exactly their own two files (positive control)');
select is((select count(*)::int from storage.objects where bucket_id = 'lab-reports' and name like '00000000-0000-0000-0000-0000000a6002/%'),
  0, 'patient A1 cannot read or list same-clinic patient A2 files');
select is((select count(*)::int from storage.objects where bucket_id = 'lab-reports' and name like '00000000-0000-0000-0000-0000000b1001/%'),
  0, 'patient A1 cannot read or list other-clinic patient B1 files');
select lives_ok($$ insert into storage.objects (bucket_id, name) values ('lab-reports', '00000000-0000-0000-0000-0000000a1001/36a00000-0000-4000-8000-0000000000a5.pdf') $$,
  'patient A1 can upload a uuid-named file into their own folder');
select throws_ok($$ insert into storage.objects (bucket_id, name) values ('lab-reports', '00000000-0000-0000-0000-0000000a6002/36a00000-0000-4000-8000-0000000000a6.pdf') $$,
  '42501', null, 'patient A1 cannot write into same-clinic patient A2 folder');
select throws_ok($$ insert into storage.objects (bucket_id, name) values ('lab-reports', '00000000-0000-0000-0000-0000000b1001/36a00000-0000-4000-8000-0000000000a7.pdf') $$,
  '42501', null, 'patient A1 cannot write into other-clinic patient B1 folder');
select throws_ok($$ insert into storage.objects (bucket_id, name) values ('lab-reports', '00000000-0000-0000-0000-0000000a1001/My Labs.pdf') $$,
  '42501', null, 'patient A1 cannot upload a free-form file name (only <uuid>.<ext>)');
select throws_ok($$ insert into storage.objects (bucket_id, name) values ('lab-reports', '00000000-0000-0000-0000-0000000a1001/x/36a00000-0000-4000-8000-0000000000a8.pdf') $$,
  '42501', null, 'patient A1 cannot upload into a nested folder');
select throws_ok($$ insert into storage.objects (bucket_id, name) values ('lab-reports', '00000000-0000-0000-0000-0000000a1001/36a00000-0000-4000-8000-0000000000a9.exe') $$,
  '42501', null, 'patient A1 cannot upload a non-report file type');
with d as (delete from storage.objects where bucket_id = 'lab-reports' and name like '00000000-0000-0000-0000-0000000a6002/%' returning 1) insert into tc036_seen select 'a1-delete-a2', count(*) from d;
with d as (delete from storage.objects where bucket_id = 'lab-reports' and name like '00000000-0000-0000-0000-0000000b1001/%' returning 1) insert into tc036_seen select 'a1-delete-b1', count(*) from d;
with u as (update storage.objects set metadata = '{"x":1}' where bucket_id = 'lab-reports' and name not like '00000000-0000-0000-0000-0000000a1001/%' returning 1) insert into tc036_seen select 'a1-update-others', count(*) from u;
with u as (update storage.objects set name = '00000000-0000-0000-0000-0000000a1001/36a00000-0000-4000-8000-0000000000ff.pdf' where bucket_id = 'lab-reports' and name like '00000000-0000-0000-0000-0000000a6002/%' returning 1) insert into tc036_seen select 'a1-move-a2', count(*) from u;
with u as (update storage.objects set metadata = '{"x":1}' where bucket_id = 'lab-reports' and name like '00000000-0000-0000-0000-0000000a1001/%' returning 1) insert into tc036_seen select 'a1-update-own', count(*) from u;
with d as (delete from storage.objects where name = '00000000-0000-0000-0000-0000000a1001/36a00000-0000-4000-8000-000000000001.pdf' returning 1) insert into tc036_seen select 'a1-delete-own-filed', count(*) from d;
with d as (delete from storage.objects where name = '00000000-0000-0000-0000-0000000a1001/36a00000-0000-4000-8000-000000000002.pdf' returning 1) insert into tc036_seen select 'a1-delete-own-unfiled', count(*) from d;
-- pdf_path can't point a report at someone else's file
select throws_ok($$ insert into public.lab_reports (org_id, patient_id, report_type, data, pdf_path) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'patient_upload', '{}',
   '00000000-0000-0000-0000-0000000b1001/36b00000-0000-4000-8000-000000000001.pdf') $$,
  '23514', null, 'a report cannot point pdf_path at another patient''s file');
select throws_ok($$ insert into public.lab_reports (org_id, patient_id, report_type, data, pdf_path) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'patient_upload', '{}',
   'https://demo.example.test/storage/v1/object/public/lab-reports/00000000-0000-0000-0000-0000000a1001/a.pdf') $$,
  '23514', null, 'pdf_path cannot hold a URL');
reset role;
select set_config('request.jwt.claims', '', true);
select is((select n from tc036_seen where who = 'a1-delete-a2'), 0, 'patient A1 cannot delete same-clinic patient A2 files');
select is((select n from tc036_seen where who = 'a1-delete-b1'), 0, 'patient A1 cannot delete other-clinic patient B1 files');
select is((select n from tc036_seen where who = 'a1-update-others'), 0, 'patient A1 cannot overwrite other patients'' files');
select is((select n from tc036_seen where who = 'a1-move-a2'), 0, 'patient A1 cannot move another patient''s file into their folder');
select is((select n from tc036_seen where who = 'a1-update-own'), 0, 'patient A1 cannot overwrite even their own files (no upsert)');
select is((select n from tc036_seen where who = 'a1-delete-own-filed'), 0, 'patient A1 cannot delete a file a lab report points at');
select is((select n from tc036_seen where who = 'a1-delete-own-unfiled'), 1, 'patient A1 CAN delete their own unfiled upload (orphan cleanup)');
select is((select count(*)::int from storage.objects where bucket_id = 'lab-reports' and name like '00000000-0000-0000-0000-0000000a6002/%'), 2, 'A2 files untouched');
select is((select count(*)::int from storage.objects where bucket_id = 'lab-reports' and name like '00000000-0000-0000-0000-0000000b1001/%'), 1, 'B1 file untouched');

-- Patient B1 (clinic B) sees only their own.
select tests.authenticate_as('00000000-0000-0000-0000-0000000b1001', 'aal1');
select is((select array_agg(name) from storage.objects where bucket_id = 'lab-reports'),
  array['00000000-0000-0000-0000-0000000b1001/36b00000-0000-4000-8000-000000000001.pdf'],
  'patient B1 sees only their own file');
reset role;

-- ---------------------------------------------------------------------------
-- Clinic staff
-- ---------------------------------------------------------------------------
create or replace function pg_temp.visible() returns text[] language sql as $$
  select coalesce(array_agg(name order by name), '{}') from storage.objects where bucket_id = 'lab-reports' $$;

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select is(pg_temp.visible(),
  array['00000000-0000-0000-0000-0000000a1001/36a00000-0000-4000-8000-000000000001.pdf',
        '00000000-0000-0000-0000-0000000a6002/36a00000-0000-4000-8000-000000000003.pdf'],
  'physician A reads the filed reports of clinic A patients only (not unfiled uploads, not clinic B)');
select throws_ok($$ insert into storage.objects (bucket_id, name) values ('lab-reports', '00000000-0000-0000-0000-0000000a1001/36a00000-0000-4000-8000-0000000000b1.pdf') $$,
  '42501', null, 'physician A cannot upload into a patient folder');
with d as (delete from storage.objects where bucket_id = 'lab-reports' returning 1) insert into tc036_seen select 'phys-a-delete', count(*) from d;
with u as (update storage.objects set metadata = '{"x":1}' where bucket_id = 'lab-reports' returning 1) insert into tc036_seen select 'phys-a-update', count(*) from u;
reset role;
select is((select array_agg(n order by who) from tc036_seen where who like 'phys-a-%'), array[0, 0], 'physician A cannot delete or overwrite lab-report files');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2');
select is(pg_temp.visible(),
  array['00000000-0000-0000-0000-0000000a1001/36a00000-0000-4000-8000-000000000001.pdf',
        '00000000-0000-0000-0000-0000000a6002/36a00000-0000-4000-8000-000000000003.pdf'],
  'care coordinator A reads the filed reports of clinic A patients only');
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal1');
select is(pg_temp.visible(), '{}'::text[], 'physician A without aal2 reads nothing');
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2');
select is(pg_temp.visible(), '{}'::text[], 'read_only A reads nothing (no raw reports, H2)');
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
select is(pg_temp.visible(), '{}'::text[], 'org_admin A reads nothing (admins manage users only)');
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2');
select is(pg_temp.visible(),
  array['00000000-0000-0000-0000-0000000b1001/36b00000-0000-4000-8000-000000000001.pdf'],
  'physician B reads clinic B only, nothing from clinic A');
reset role;
select set_config('request.jwt.claims', '', true);

-- ---------------------------------------------------------------------------
-- Patient gates: an unlinked or unconfirmed account reaches nothing, even in
-- its own folder (same gates as lab_reports_self_*).
-- ---------------------------------------------------------------------------
update public.patient_record_links set status = 'revoked' where app_user_id = '00000000-0000-0000-0000-0000000a6002';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a6002', 'aal1');
select is(pg_temp.visible(), '{}'::text[], 'unlinked patient A2 cannot read their own folder');
select throws_ok($$ insert into storage.objects (bucket_id, name) values ('lab-reports', '00000000-0000-0000-0000-0000000a6002/36a00000-0000-4000-8000-0000000000c1.pdf') $$,
  '42501', null, 'unlinked patient A2 cannot upload');
reset role;
update public.patient_record_links set status = 'active' where app_user_id = '00000000-0000-0000-0000-0000000a6002';
update auth.users set email_confirmed_at = null where id = '00000000-0000-0000-0000-0000000a6002';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a6002', 'aal1');
select is(pg_temp.visible(), '{}'::text[], 'unconfirmed-email patient A2 cannot read their own folder');
with d as (delete from storage.objects where name = '00000000-0000-0000-0000-0000000a6002/36a00000-0000-4000-8000-000000000004.pdf' returning 1) insert into tc036_seen select 'a2-unconfirmed-delete', count(*) from d;
reset role;
select is((select n from tc036_seen where who = 'a2-unconfirmed-delete'), 0, 'unconfirmed-email patient A2 cannot delete');

-- ---------------------------------------------------------------------------
-- Defense in depth: if a lab_reports policy is ever widened to another staff
-- role, the storage policy still only serves physician / care coordinator.
-- (Policy added inside this rolled-back transaction only.)
-- ---------------------------------------------------------------------------
create policy tc036_probe_widened on public.lab_reports for select to authenticated using (org_id = public.current_org_id());
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2');
select ok((select count(*) from public.lab_reports) > 0, 'probe: widened lab_reports policy lets read_only A see rows');
select is(pg_temp.visible(), '{}'::text[], 'read_only A still reads no lab-report files');
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
select is(pg_temp.visible(), '{}'::text[], 'org_admin A still reads no lab-report files');
reset role;
drop policy tc036_probe_widened on public.lab_reports;

-- ---------------------------------------------------------------------------
-- M1 (Clara, PR #33 r1): a lab_reports row filed under one clinic never opens
-- another clinic's patient folder. Forged rows in both directions:
--   * clinic-B row naming clinic-A patient A1 and A1's object (Clara's attack:
--     physician B inserts it today, or re-points a B row; the write path is
--     closed separately by TC-040, so the row is written service-side here
--     and the test holds before and after TC-040);
--   * clinic-A row naming clinic-B patient B1 and B1's object.
-- Neither object is filed by its own patient's clinic.
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', '', true);
insert into storage.objects (bucket_id, name) values
  ('lab-reports', '00000000-0000-0000-0000-0000000a1001/36a00000-0000-4000-8000-000000000006.pdf'), -- A1, filed only by a clinic-B row
  ('lab-reports', '00000000-0000-0000-0000-0000000b1001/36b00000-0000-4000-8000-000000000002.pdf'); -- B1, filed only by a clinic-A row
insert into public.lab_reports (id, org_id, patient_id, report_type, data, pdf_path) values
  ('00000000-0000-0000-0000-00000036b302', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000a1001', 'fictional_forged', '{}',
   '00000000-0000-0000-0000-0000000a1001/36a00000-0000-4000-8000-000000000006.pdf'),
  ('00000000-0000-0000-0000-00000036a303', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000b1001', 'fictional_forged', '{}',
   '00000000-0000-0000-0000-0000000b1001/36b00000-0000-4000-8000-000000000002.pdf');

select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2');
select ok((select count(*) from public.lab_reports where id = '00000000-0000-0000-0000-00000036b302') = 1,
  'M1 precondition: physician B can read the forged clinic-B row that names A1''s file');
select is((select count(*)::int from storage.objects
            where name = '00000000-0000-0000-0000-0000000a1001/36a00000-0000-4000-8000-000000000006.pdf'),
  0, 'M1: physician B cannot read or sign clinic-A patient A1''s file through a forged clinic-B row');
select is(pg_temp.visible(),
  array['00000000-0000-0000-0000-0000000b1001/36b00000-0000-4000-8000-000000000001.pdf'],
  'physician B still reads only B1''s report filed by clinic B (not A1''s file, not a B1 file filed only by clinic A)');
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select is((select count(*)::int from storage.objects
            where name = '00000000-0000-0000-0000-0000000b1001/36b00000-0000-4000-8000-000000000002.pdf'),
  0, 'M1 mirror: physician A cannot read clinic-B patient B1''s file through a forged clinic-A row');
select is(pg_temp.visible(),
  array['00000000-0000-0000-0000-0000000a1001/36a00000-0000-4000-8000-000000000001.pdf',
        '00000000-0000-0000-0000-0000000a6002/36a00000-0000-4000-8000-000000000003.pdf'],
  'physician A still reads only clinic-A files filed by clinic A (not A1''s file filed only by clinic B)');
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2');
select is(pg_temp.visible(),
  array['00000000-0000-0000-0000-0000000a1001/36a00000-0000-4000-8000-000000000001.pdf',
        '00000000-0000-0000-0000-0000000a6002/36a00000-0000-4000-8000-000000000003.pdf'],
  'care coordinator A: same, forged rows open nothing');
reset role;
select set_config('request.jwt.claims', '', true);
-- The clinic filter on the ROW is not just lab_reports RLS: if a lab_reports
-- SELECT policy were ever widened to other clinics' rows (probe, this
-- rolled-back transaction only), a row filed by another clinic still opens
-- nothing, even for a patient of the caller's own clinic.
create policy tc036_probe_lab_reports_all on public.lab_reports for select to authenticated using (true);
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2');
select ok((select count(*) from public.lab_reports where id = '00000000-0000-0000-0000-00000036a303') = 1,
  'probe: widened lab_reports policy shows physician B the clinic-A row naming B1''s file');
select is((select count(*)::int from storage.objects
            where name = '00000000-0000-0000-0000-0000000b1001/36b00000-0000-4000-8000-000000000002.pdf'),
  0, 'physician B cannot open B1''s file through a row filed by clinic A, even when that row is visible');
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select is((select count(*)::int from storage.objects
            where name = '00000000-0000-0000-0000-0000000a1001/36a00000-0000-4000-8000-000000000006.pdf'),
  0, 'physician A cannot open A1''s file through a row filed by clinic B, even when that row is visible');
reset role;
drop policy tc036_probe_lab_reports_all on public.lab_reports;
select set_config('request.jwt.claims', '', true);

-- ---------------------------------------------------------------------------
-- Exact folder segment, never a prefix: objects whose names merely START with
-- A1's id (a sibling folder, a root-level name) are not A1's. Service-written;
-- patients can't create such names (insert regex), but a LIKE uid||'%' read
-- or delete rule would hand them to A1.
-- ---------------------------------------------------------------------------
insert into storage.objects (bucket_id, name) values
  ('lab-reports', '00000000-0000-0000-0000-0000000a10010/36a00000-0000-4000-8000-000000000007.pdf'), -- sibling folder
  ('lab-reports', '00000000-0000-0000-0000-0000000a1001.pdf');                                       -- root-level, same prefix
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1');
select is((select count(*)::int from storage.objects
            where bucket_id = 'lab-reports' and name like '00000000-0000-0000-0000-0000000a1001%'
              and split_part(name, '/', 1) <> '00000000-0000-0000-0000-0000000a1001'),
  0, 'patient A1 cannot read objects whose name only starts with their id (sibling folder / root name)');
reset role;

-- ---------------------------------------------------------------------------
-- The delete rule holds on its own: with an extra (probe) SELECT policy that
-- shows every lab-reports object, a patient still deletes only their OWN
-- unfiled uploads. (DELETE also needs SELECT visibility, which otherwise
-- masks a missing own-folder check here. Probe lives only in this rolled-back
-- transaction.)
-- ---------------------------------------------------------------------------
create policy tc036_probe_select_all on storage.objects for select to authenticated using (bucket_id = 'lab-reports');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1');
select ok((select count(*) from storage.objects where name = '00000000-0000-0000-0000-0000000a6002/36a00000-0000-4000-8000-000000000004.pdf') = 1,
  'probe: widened SELECT shows A1 the unfiled A2 file');
with d as (delete from storage.objects where name = '00000000-0000-0000-0000-0000000a6002/36a00000-0000-4000-8000-000000000004.pdf' returning 1) insert into tc036_seen select 'probe-a1-delete-a2-unfiled', count(*) from d;
with d as (delete from storage.objects where name in ('00000000-0000-0000-0000-0000000a10010/36a00000-0000-4000-8000-000000000007.pdf', '00000000-0000-0000-0000-0000000a1001.pdf') returning 1) insert into tc036_seen select 'probe-a1-delete-sibling', count(*) from d;
with d as (delete from storage.objects where name = '00000000-0000-0000-0000-0000000a1001/36a00000-0000-4000-8000-0000000000a5.pdf' returning 1) insert into tc036_seen select 'probe-a1-delete-own-unfiled', count(*) from d;
reset role;
drop policy tc036_probe_select_all on storage.objects;
select is((select n from tc036_seen where who = 'probe-a1-delete-a2-unfiled'), 0, 'delete rule alone: A1 cannot delete same-clinic patient A2''s unfiled file');
select is((select n from tc036_seen where who = 'probe-a1-delete-sibling'), 0, 'delete rule alone: A1 cannot delete objects whose name only starts with their id');
select is((select n from tc036_seen where who = 'probe-a1-delete-own-unfiled'), 1, 'delete rule alone: A1 still deletes their own unfiled upload (positive control)');

-- ---------------------------------------------------------------------------
-- Saved link -> path conversion
-- ---------------------------------------------------------------------------
select is(public.lab_report_path_from_saved_url(v, '00000000-0000-0000-0000-0000000a1001'), want, label)
  from (values
    ('https://abc.supabase.co/storage/v1/object/public/lab-reports/00000000-0000-0000-0000-0000000a1001/Blood_Test.pdf',
     '00000000-0000-0000-0000-0000000a1001/Blood_Test.pdf', 'public URL -> path'),
    ('https://abc.supabase.co/storage/v1/object/sign/lab-reports/00000000-0000-0000-0000-0000000a1001/r.pdf?token=fictional',
     '00000000-0000-0000-0000-0000000a1001/r.pdf', 'signed URL -> path, token dropped'),
    ('  00000000-0000-0000-0000-0000000a1001/r.pdf ', '00000000-0000-0000-0000-0000000a1001/r.pdf', 'bare path kept'),
    ('lab-reports/00000000-0000-0000-0000-0000000a1001/r.pdf', '00000000-0000-0000-0000-0000000a1001/r.pdf', 'bucket-prefixed path'),
    ('https://abc.supabase.co/storage/v1/object/public/lab-reports/00000000-0000-0000-0000-0000000b1001/r.pdf', null, 'another patient''s folder -> null'),
    ('https://abc.supabase.co/storage/v1/object/public/food-images/00000000-0000-0000-0000-0000000a1001/r.pdf', null, 'another bucket -> null'),
    ('https://abc.supabase.co/storage/v1/object/public/lab-reports/00000000-0000-0000-0000-0000000a1001/../00000000-0000-0000-0000-0000000b1001/r.pdf', null, 'traversal -> null'),
    ('https://abc.supabase.co/storage/v1/object/public/lab-reports/00000000-0000-0000-0000-0000000a1001/My%20Labs.pdf', null, 'percent-encoded -> null'),
    ('https://cdn.example.test/files/r.pdf', null, 'not a storage URL -> null'),
    ('', null, 'empty -> null')
  ) t(v, want, label);

insert into public.lab_reports (id, org_id, patient_id, report_type, data) values
  ('00000000-0000-0000-0000-00000036c001', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'legacy', jsonb_build_object('title', 'Fictional legacy',
     'pdf_url', 'https://abc.supabase.co/storage/v1/object/public/lab-reports/00000000-0000-0000-0000-0000000a1001/Legacy_Panel.pdf')),
  ('00000000-0000-0000-0000-00000036c002', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'legacy', jsonb_build_object('title', 'Fictional bad',
     'pdf_url', 'https://abc.supabase.co/storage/v1/object/public/lab-reports/00000000-0000-0000-0000-0000000b1001/x.pdf'));
select is((select row(converted, quarantined)::text from public.lab_reports_convert_saved_pdf_urls()), '(1,1)', 'conversion: one converted, one quarantined');
select is((select pdf_path from public.lab_reports where id = '00000000-0000-0000-0000-00000036c001'),
  '00000000-0000-0000-0000-0000000a1001/Legacy_Panel.pdf', 'good link became pdf_path');
select is((select pdf_path from public.lab_reports where id = '00000000-0000-0000-0000-00000036c002'), null, 'bad link got no pdf_path');
select is((select count(*)::int from public.lab_reports where data ? 'pdf_url'), 0, 'no saved link remains in any lab_reports payload');
select is((select data ->> 'title' from public.lab_reports where id = '00000000-0000-0000-0000-00000036c001'), 'Fictional legacy', 'rest of the payload kept');
select is((select raw_value from public.lab_report_pdf_url_quarantine where lab_report_id = '00000000-0000-0000-0000-00000036c002'),
  'https://abc.supabase.co/storage/v1/object/public/lab-reports/00000000-0000-0000-0000-0000000b1001/x.pdf', 'bad link kept in quarantine for review');
select is((select row(converted, quarantined)::text from public.lab_reports_convert_saved_pdf_urls()), '(0,0)', 're-running the conversion is a no-op');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1');
select throws_ok($$ select count(*) from public.lab_report_pdf_url_quarantine $$, '42501', null, 'patients cannot read the quarantine');
select throws_ok($$ select public.lab_reports_convert_saved_pdf_urls() $$, '42501', null, 'patients cannot run the conversion');
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select throws_ok($$ select count(*) from public.lab_report_pdf_url_quarantine $$, '42501', null, 'staff cannot read the quarantine');
reset role;

select * from finish();
rollback;
