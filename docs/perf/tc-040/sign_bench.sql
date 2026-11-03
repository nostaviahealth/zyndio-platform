-- TC-040 item 6: timing check for clinic-staff signed links on lab-report files.
-- LOCAL ONLY, fictional data, everything inside one transaction that is rolled
-- back. Run with scripts/bench-lab-reports-sign.sh (never against a remote DB).
--
-- Scale: 2 clinics x 10,000 fictional patients, one filed PDF each (20,000
-- storage.objects + 20,000 lab_reports rows). A physician of clinic X then
-- "signs" 500 different own-clinic files. storage-api mints a signed URL only
-- after an RLS-checked SELECT of the object row as the caller, so each sample
-- is exactly that SELECT (EXECUTE, so it is planned per call like a request).
-- Budget: every sample under 5 ms. Prints p50/p95/p99/max and PASS/FAIL.
\set ON_ERROR_STOP 1
\pset pager off
begin;
select set_config('storage.allow_delete_query', 'true', true);

insert into public.organizations (id, name) values
  ('0000c040-0000-0000-0000-00000000000a', 'Fictional Bench Clinic X'),
  ('0000c040-0000-0000-0000-00000000000b', 'Fictional Bench Clinic Y');
insert into auth.users (id, email, email_confirmed_at, aud, role) values
  ('0000c040-0000-0000-0000-0000000a0002', 'bench-physician-x@example.test', now(), 'authenticated', 'authenticated'),
  ('0000c040-0000-0000-0000-0000000b0002', 'bench-physician-y@example.test', now(), 'authenticated', 'authenticated');
insert into public.org_members (user_id, org_id, role, status) values
  ('0000c040-0000-0000-0000-0000000a0002', '0000c040-0000-0000-0000-00000000000a', 'physician', 'active'),
  ('0000c040-0000-0000-0000-0000000b0002', '0000c040-0000-0000-0000-00000000000b', 'physician', 'active');

-- patient g: id 0000c040-0000-4000-9000-<g>, clinic X for even g, Y for odd g.
insert into auth.users (id, email, email_confirmed_at, aud, role)
select ('0000c040-0000-4000-9000-' || lpad(to_hex(g), 12, '0'))::uuid,
       'bench-patient-' || g || '@example.test', now(), 'authenticated', 'authenticated'
  from generate_series(1, 20000) g;
insert into public.patients (id, org_id, display_name, mrn)
select ('0000c040-0000-4000-9000-' || lpad(to_hex(g), 12, '0'))::uuid,
       case when g % 2 = 0 then '0000c040-0000-0000-0000-00000000000a'::uuid
            else '0000c040-0000-0000-0000-00000000000b'::uuid end,
       'Fictional Bench Patient ' || g, 'BENCH-' || g
  from generate_series(1, 20000) g;
insert into storage.objects (bucket_id, name)
select 'lab-reports', '0000c040-0000-4000-9000-' || lpad(to_hex(g), 12, '0') || '/' || gen_random_uuid() || '.pdf'
  from generate_series(1, 20000) g;
-- a few non-uuid first segments (legacy/hand-made objects) must not break anything
insert into storage.objects (bucket_id, name) values
  ('lab-reports', 'not-a-uuid/legacy.pdf'), ('lab-reports', 'legacy.pdf'),
  ('lab-reports', '0000C040-0000-4000-9000-000000000002/upper.pdf');
insert into public.lab_reports (org_id, patient_id, report_type, data, pdf_path)
select p.org_id, p.id, 'bench', '{}', o.name
  from storage.objects o
  join public.patients p on p.id::text = split_part(o.name, '/', 1)
 where o.bucket_id = 'lab-reports' and o.name like '0000c040-0000-4000-9000-%';
analyze public.patients; analyze public.lab_reports; analyze storage.objects;

create temp table bench_names on commit drop as
select o.name, p.org_id = '0000c040-0000-0000-0000-00000000000a'::uuid as own
  from storage.objects o join public.patients p on p.id::text = split_part(o.name, '/', 1)
 where o.bucket_id = 'lab-reports' and o.name like '0000c040-0000-4000-9000-%';
create temp table bench_ms (i int, ms numeric, seen boolean) on commit drop;
grant select on bench_names to authenticated;
grant insert, select on bench_ms to authenticated;

select 'patients_per_clinic', org_id, count(*) from public.patients
 where org_id in ('0000c040-0000-0000-0000-00000000000a', '0000c040-0000-0000-0000-00000000000b')
 group by org_id order by org_id;
select 'policy', pg_get_expr(polqual, polrelid) ~ 'split_part\(.*\)::uuid' as uuid_compare
  from pg_policy where polname = 'lab_reports_objects_staff_select';

-- physician of clinic X, aal2 (what PostgREST/storage-api sets from the JWT)
select set_config('request.jwt.claims',
  json_build_object('sub', '0000c040-0000-0000-0000-0000000a0002', 'role', 'authenticated', 'aal', 'aal2')::text, true);
set local role authenticated;

do $$
declare
  v_name text; v_t0 timestamptz; v_hit int; i int := 0;
begin
  -- warm-up (connection caches), not recorded
  for v_name in select name from bench_names where own order by name limit 20 loop
    execute 'select count(*) from storage.objects where bucket_id = $1 and name = $2' into v_hit using 'lab-reports', v_name;
  end loop;
  for v_name in select name from bench_names where own order by md5(name) limit 500 loop
    i := i + 1;
    v_t0 := clock_timestamp();
    execute 'select count(*) from storage.objects where bucket_id = $1 and name = $2' into v_hit using 'lab-reports', v_name;
    insert into bench_ms values (i, extract(epoch from clock_timestamp() - v_t0) * 1000, v_hit = 1);
  end loop;
end;
$$;

select 'own_clinic_signs' as what, count(*) as n, count(*) filter (where seen) as allowed,
       round(percentile_cont(0.5) within group (order by ms)::numeric, 3) as p50_ms,
       round(percentile_cont(0.95) within group (order by ms)::numeric, 3) as p95_ms,
       round(percentile_cont(0.99) within group (order by ms)::numeric, 3) as p99_ms,
       round(max(ms), 3) as max_ms,
       case when max(ms) < 5 and count(*) filter (where seen) = 500 then 'PASS (every sign < 5 ms)' else 'FAIL' end as budget
  from bench_ms;

-- other clinic's files: refused (0 rows), and the non-uuid objects don't error
select 'other_clinic_file_visible', count(*) from storage.objects
 where bucket_id = 'lab-reports' and name = (select name from bench_names where not own order by name limit 1);
select 'non_uuid_objects_visible', count(*) from storage.objects
 where bucket_id = 'lab-reports' and name in ('not-a-uuid/legacy.pdf', 'legacy.pdf', '0000C040-0000-4000-9000-000000000002/upper.pdf');

select name as one_own_name from bench_names where own order by name limit 1 \gset
explain (analyze, costs off, summary on, timing on)
select name from storage.objects
 where bucket_id = 'lab-reports' and name = :'one_own_name';

rollback;
