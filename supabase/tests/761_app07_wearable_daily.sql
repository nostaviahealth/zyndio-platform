-- APP-07: wearable_daily - patients write and read only their own daily
-- wearable rows; a repeat upload (upsert on patient + date + metric + source)
-- replaces the value instead of adding a row; physician / care coordinator of
-- the patient's clinic read them; read_only, org_admin, other clinics, other
-- patients and anon get nothing; no client delete; patient_id / org_id are
-- immutable; unknown metrics, wrong units and implausible values are refused.
-- Fixture actors from 000_fixtures.sql. Fictional data only.
begin;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);

-- Patient A1 a1001 (clinic A), patient B1 b1001 (clinic B); physician A a0002,
-- coordinator A a0003, read_only A a0004, org_admin A a0001, physician B b0001.
-- B1 already has one row (written service-side).
insert into public.wearable_daily (org_id, patient_id, metric_date, metric, value, unit, source_app, source_device, coverage) values
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000b1001', date '2026-10-01',
   'steps', 4321, 'count', 'com.example.fictional.tracker', 'watch', 0.5);

create temp table app07_seen (who text, n int);
grant all on app07_seen to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Table shape and privileges
-- ---------------------------------------------------------------------------
select has_table('public', 'wearable_daily', 'wearable_daily exists');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid = 'public.wearable_daily'::regclass),
  'wearable_daily has RLS enabled and forced');
select ok(not has_table_privilege('anon', 'public.wearable_daily', 'select'), 'anon has no SELECT grant');
select ok(not has_table_privilege('anon', 'public.wearable_daily', 'insert'), 'anon has no INSERT grant');
select ok(not has_table_privilege('authenticated', 'public.wearable_daily', 'delete'), 'authenticated has no DELETE grant');
select ok(not has_table_privilege('authenticated', 'public.wearable_daily', 'truncate'), 'authenticated has no TRUNCATE grant');
select ok(not has_column_privilege('authenticated', 'public.wearable_daily', 'created_at', 'update'), 'created_at is server-owned');
select ok(not has_column_privilege('authenticated', 'public.wearable_daily', 'updated_at', 'insert'), 'updated_at is server-owned');
select ok(not has_table_privilege('anon', 'public.wearable_daily_selected', 'select'), 'anon cannot read wearable_daily_selected');
select ok(not has_function_privilege('authenticated', 'public._wearable_daily_before_write()', 'execute'),
  'the trigger function is not client-callable');

-- ---------------------------------------------------------------------------
-- Patient A1 writes own rows; the upsert key makes a repeat upload idempotent
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001');
select lives_ok($$ insert into public.wearable_daily (org_id, patient_id, metric_date, metric, value, unit, source_app, source_device, coverage, selected) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', date '2026-10-01', 'steps', 8000, 'count', 'com.example.fictional.watch', 'watch', 0.625, true),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', date '2026-10-01', 'steps', 6500, 'count', 'com.example.fictional.phone', 'phone', 0.5, false),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', date '2026-10-01', 'hrv_sdnn', 42, 'ms', 'com.example.fictional.watch', 'watch', null, true),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', date '2026-10-01', 'hrv_rmssd', 35, 'ms', 'com.example.fictional.ring', 'ring', null, true),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', date '2026-10-02', 'sleep_minutes', 431, 'min', 'com.example.fictional.watch', 'watch', null, true) $$,
  'patient A1 uploads own daily rows (several sources, HRV SDNN and RMSSD kept apart)');
-- Same key again with a new value: the app's upsert (PostgREST merge-duplicates).
select lives_ok($$ insert into public.wearable_daily (org_id, patient_id, metric_date, metric, value, unit, source_app, source_device, coverage, selected) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', date '2026-10-01', 'steps', 9100, 'count', 'com.example.fictional.watch', 'watch', 0.75, true)
  on conflict (patient_id, metric_date, metric, source_app) do update set
    org_id = excluded.org_id, patient_id = excluded.patient_id, metric_date = excluded.metric_date,
    metric = excluded.metric, value = excluded.value, unit = excluded.unit, source_app = excluded.source_app,
    source_device = excluded.source_device, coverage = excluded.coverage, selected = excluded.selected $$,
  'patient A1 re-uploads the same day (upsert)');
select lives_ok($$ insert into public.wearable_daily (org_id, patient_id, metric_date, metric, value, unit, source_app, source_device, coverage, selected) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', date '2026-10-01', 'steps', 9100, 'count', 'com.example.fictional.watch', 'watch', 0.75, true)
  on conflict (patient_id, metric_date, metric, source_app) do update set value = excluded.value, coverage = excluded.coverage $$,
  'and once more with identical values');
insert into app07_seen select 'a1-steps-watch-rows', count(*) from public.wearable_daily
  where metric_date = '2026-10-01' and metric = 'steps' and source_app = 'com.example.fictional.watch';
insert into app07_seen select 'a1-steps-watch-value', value::int from public.wearable_daily
  where metric_date = '2026-10-01' and metric = 'steps' and source_app = 'com.example.fictional.watch';
insert into app07_seen select 'a1-selected-steps', value::int from public.wearable_daily_selected
  where metric_date = '2026-10-01' and metric = 'steps';
insert into app07_seen select 'a1-selected-steps-rows', count(*) from public.wearable_daily_selected
  where metric_date = '2026-10-01' and metric = 'steps';
insert into app07_seen select 'a1-sees-all', count(*) from public.wearable_daily;
reset role;
select is((select n from app07_seen where who = 'a1-steps-watch-rows'), 1, 'repeat uploads leave exactly one row per patient + date + metric + source');
select is((select n from app07_seen where who = 'a1-steps-watch-value'), 9100, 'the repeat upload replaced the value (not added to it)');
select is((select n from app07_seen where who = 'a1-selected-steps-rows'), 1, 'wearable_daily_selected has one steps row for the day');
select is((select n from app07_seen where who = 'a1-selected-steps'), 9100, 'and it is the selected source''s value, not the sum of sources');
select is((select n from app07_seen where who = 'a1-sees-all'), 5, 'patient A1 sees only their own 5 rows (not B1''s)');
select is((select count(*)::int from public.wearable_daily
            where patient_id = '00000000-0000-0000-0000-0000000a1001' and metric in ('hrv_sdnn', 'hrv_rmssd')), 2,
  'HRV SDNN and RMSSD are separate metrics');

-- ---------------------------------------------------------------------------
-- Patient A1 cannot write for someone else or into another clinic
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001');
select throws_ok($$ insert into public.wearable_daily (org_id, patient_id, metric_date, metric, value, unit, source_app) values
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000b1001', date '2026-10-03', 'steps', 1, 'count', 'com.example.fictional.watch') $$,
  '42501', null, 'patient A1 cannot write a row for patient B1');
select throws_ok($$ insert into public.wearable_daily (org_id, patient_id, metric_date, metric, value, unit, source_app) values
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000a1001', date '2026-10-03', 'steps', 1, 'count', 'com.example.fictional.watch') $$,
  '42501', null, 'patient A1 cannot file own row under clinic B');
-- B1's row is invisible to A1, so an update or upsert can't touch it.
with u as (update public.wearable_daily set value = 1 where patient_id = '00000000-0000-0000-0000-0000000b1001' returning 1)
  insert into app07_seen select 'a1-updates-b1', count(*) from u;
select throws_ok($$ delete from public.wearable_daily where patient_id = '00000000-0000-0000-0000-0000000a1001' $$,
  '42501', null, 'patient A1 cannot delete own rows (no client delete)');
reset role;
select is((select n from app07_seen where who = 'a1-updates-b1'), 0, 'patient A1 cannot update patient B1''s rows');
select is((select value::int from public.wearable_daily where patient_id = '00000000-0000-0000-0000-0000000b1001'), 4321, 'B1''s row is unchanged');
select is((select count(*)::int from public.wearable_daily where patient_id = '00000000-0000-0000-0000-0000000a1001'), 5, 'patient A1 deleted nothing');

-- ---------------------------------------------------------------------------
-- patient_id / org_id are immutable for clients
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001');
select throws_ok($$ update public.wearable_daily set org_id = '00000000-0000-0000-0000-00000000000b'
  where patient_id = '00000000-0000-0000-0000-0000000a1001' and metric = 'sleep_minutes' $$,
  '42501', null, 'patient A1 cannot move a row to clinic B');
select throws_ok($$ update public.wearable_daily set patient_id = '00000000-0000-0000-0000-0000000b1001'
  where patient_id = '00000000-0000-0000-0000-0000000a1001' and metric = 'sleep_minutes' $$,
  '42501', null, 'patient A1 cannot hand a row to patient B1');
reset role;

-- ---------------------------------------------------------------------------
-- Bad data is refused
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001');
select throws_ok($$ insert into public.wearable_daily (org_id, patient_id, metric_date, metric, value, unit, source_app) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', date '2026-10-03', 'mood_score', 5, 'count', 'com.example.fictional.watch') $$,
  '23514', null, 'an unknown metric is refused');
select throws_ok($$ insert into public.wearable_daily (org_id, patient_id, metric_date, metric, value, unit, source_app) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', date '2026-10-03', 'weight_kg', 180, 'lb', 'com.example.fictional.scale') $$,
  '23514', null, 'a metric in the wrong unit is refused');
select throws_ok($$ insert into public.wearable_daily (org_id, patient_id, metric_date, metric, value, unit, source_app) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', date '2026-10-03', 'resting_hr', 400, 'bpm', 'com.example.fictional.watch') $$,
  '23514', null, 'an implausible value is refused');
select throws_ok($$ insert into public.wearable_daily (org_id, patient_id, metric_date, metric, value, unit, source_app) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', date '2026-10-03', 'spo2', 97, '%', 'com.example.fictional.watch'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', date '2026-10-03', 'spo2', 0.97, '%', 'com.example.fictional.ring') $$,
  '23514', null, 'SpO2 as a fraction (unit error) is refused, and the whole batch with it');
select throws_ok($$ insert into public.wearable_daily (org_id, patient_id, metric_date, metric, value, unit, source_app) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', current_date + 30, 'steps', 10, 'count', 'com.example.fictional.watch') $$,
  '22023', null, 'a date in the future is refused');
select throws_ok($$ insert into public.wearable_daily (org_id, patient_id, metric_date, metric, value, unit, source_app, coverage) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', date '2026-10-03', 'steps', 10, 'count', 'com.example.fictional.watch', 1.5) $$,
  '23514', null, 'coverage above 1 is refused');
select throws_ok($$ insert into public.wearable_daily (org_id, patient_id, metric_date, metric, value, unit, source_app, source_device) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', date '2026-10-03', 'steps', 10, 'count', 'com.example.fictional.watch', 'Fictional Person''s Watch') $$,
  '23514', null, 'source_device is a device class, never a display name');
select throws_ok($$ insert into public.wearable_daily (org_id, patient_id, metric_date, metric, value, unit, source_app, created_at) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', date '2026-10-03', 'steps', 10, 'count', 'com.example.fictional.watch', now() - interval '1 year') $$,
  '42501', null, 'a client cannot set created_at');
reset role;

-- ---------------------------------------------------------------------------
-- Staff reads: own clinic physician / coordinator only
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
insert into app07_seen select 'phys-a', count(*) from public.wearable_daily;
insert into app07_seen select 'phys-a-selected', count(*) from public.wearable_daily_selected;
select throws_ok($$ insert into public.wearable_daily (org_id, patient_id, metric_date, metric, value, unit, source_app) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', date '2026-10-04', 'steps', 1, 'count', 'com.example.fictional.watch') $$,
  '42501', null, 'physician A cannot write wearable rows for a patient');
with u as (update public.wearable_daily set value = 1 returning 1)
  insert into app07_seen select 'phys-a-update', count(*) from u;
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal1');
insert into app07_seen select 'phys-a-aal1', count(*) from public.wearable_daily;
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2');
insert into app07_seen select 'coord-a', count(*) from public.wearable_daily;
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2');
insert into app07_seen select 'read-only-a', count(*) from public.wearable_daily;
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
insert into app07_seen select 'org-admin-a', count(*) from public.wearable_daily;
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2');
insert into app07_seen select 'phys-b', count(*) from public.wearable_daily;
insert into app07_seen select 'phys-b-a1', count(*) from public.wearable_daily where patient_id = '00000000-0000-0000-0000-0000000a1001';
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000b1001');
insert into app07_seen select 'patient-b1', count(*) from public.wearable_daily;
reset role;
select tests.authenticate_as_anon();
select throws_ok($$ select count(*) from public.wearable_daily $$, '42501', null, 'anon cannot read wearable_daily');
select throws_ok($$ select count(*) from public.wearable_daily_selected $$, '42501', null, 'anon cannot read wearable_daily_selected');
reset role;

select is((select n from app07_seen where who = 'phys-a'), 5, 'physician A reads clinic-A patient A1''s rows only');
select is((select n from app07_seen where who = 'phys-a-selected'), 4, 'physician A reads one selected row per date + metric');
select is((select n from app07_seen where who = 'phys-a-update'), 0, 'physician A cannot update wearable rows');
select is((select n from app07_seen where who = 'phys-a-aal1'), 0, 'staff without aal2 read nothing');
select is((select n from app07_seen where who = 'coord-a'), 5, 'care coordinator A reads clinic-A rows');
select is((select n from app07_seen where who = 'read-only-a'), 0, 'read_only reads no wearable detail');
select is((select n from app07_seen where who = 'org-admin-a'), 0, 'org_admin reads no wearable detail');
select is((select n from app07_seen where who = 'phys-b'), 1, 'physician B reads only clinic-B rows');
select is((select n from app07_seen where who = 'phys-b-a1'), 0, 'physician B reads none of clinic-A patient A1''s rows');
select is((select n from app07_seen where who = 'patient-b1'), 1, 'patient B1 reads only their own row');

select * from finish();
rollback;
