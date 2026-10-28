-- TC-015 slice 1 (physician list + detail), fail-first RLS isolation.
--
-- Leo ruling, fix round (28 Oct, supersedes R1 26 Oct): physician,
-- care_coordinator and read_only all see the list, detail and trends for
-- their own clinic; every detail open is audited; read_only gets no actions
-- (enforced by every write/action RPC and by the absence of any insert/
-- update/delete grant on the clinical tables - see the read_only block
-- below). Another clinic's patient is invisible to every role, identical
-- not-found (never a distinct "forbidden") whether cross-org or unknown id.
--
-- Fixtures are built inside this file's own transaction (as the pg_prove
-- superuser, before authenticate_as) with TC-015-namespaced UUIDs, and rolled
-- back at the end, so nothing leaks into the shared 000_fixtures state or
-- other test files. Expect this file to FAIL until the schema, RLS and RPCs
-- land (public.lab_results / patient_treatments / patient_roster_meta,
-- physician_patient_roster, patient_trend, open_patient_detail).
begin;
select no_plan();

-- ---------------------------------------------------------------------------
-- Fixtures: a visible report + results for org A patient a1001, and a report +
-- results for org B patient b1001, plus roster meta for both.
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', '', true);

insert into public.lab_reports (id, org_id, patient_id, report_type, data, identity_hold) values
  ('00000000-0000-0000-0000-00000015a301', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'metabolic_panel', '{}', false),
  ('00000000-0000-0000-0000-00000015b301', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000b1001', 'metabolic_panel', '{}', false);

insert into public.lab_results
  (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value, unit, status, taken_at) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000015a301', 'hba1c', 'HbA1c', 5.5, '%', 'within_range', now() - interval '20 days'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000b1001', '00000000-0000-0000-0000-00000015b301', 'hba1c', 'HbA1c', 6.1, '%', 'within_range', now() - interval '20 days');

insert into public.patient_treatments (org_id, patient_id, name, started_on, status, source) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'Example GLP-1 medication (fictional)', date '2026-04-02', 'Active', 'Zyndio record, Oct 20, 2026');

insert into public.patient_roster_meta (patient_id, org_id, sex, birth_date, program_started_on, last_activity_at) values
  ('00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000000000a', 'F', date '1985-03-01', date '2026-04-02', now()),
  ('00000000-0000-0000-0000-0000000b1001', '00000000-0000-0000-0000-00000000000b', 'M', date '1970-01-01', date '2026-08-01', now());

-- ---------------------------------------------------------------------------
-- physician_a (same org): sees the list + detail for a1001, nothing for org B.
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a

select is(
  (select count(*) from public.lab_results where org_id = '00000000-0000-0000-0000-00000000000b')::int,
  0,
  'physician_a cannot see org B lab_results (cross-org denied)'
);
select is(
  (select count(*) from public.lab_results where patient_id = '00000000-0000-0000-0000-0000000a1001')::int,
  1,
  'physician_a sees their own org patient a1001 lab_results'
);

select is(
  (select count(*) from public.physician_patient_roster(null, 'all', 'recent', 50, 0)
    where patient_id = '00000000-0000-0000-0000-0000000a1001')::int,
  1,
  'physician_a roster includes same-org patient a1001'
);
select is(
  (select count(*) from public.physician_patient_roster(null, 'all', 'recent', 50, 0)
    where patient_id = '00000000-0000-0000-0000-0000000b1001')::int,
  0,
  'physician_a roster never includes org B patient b1001'
);

select isnt(
  (select public.open_patient_detail('00000000-0000-0000-0000-0000000a1001')),
  null,
  'physician_a can open a1001 detail'
);
select is(
  (select public.open_patient_detail('00000000-0000-0000-0000-0000000b1001')),
  null,
  'physician_a opening org B patient returns not-found (null), same as unknown'
);
select is(
  (select public.open_patient_detail('00000000-0000-0000-0000-0000009e9e9e')),
  null,
  'physician_a opening an unknown patient id returns not-found (null)'
);

select is(
  (select count(*) from public.patient_trend('00000000-0000-0000-0000-0000000a1001', 'hba1c', 'ALL'))::int,
  1,
  'physician_a gets trend points for a1001'
);
select is(
  (select count(*) from public.patient_trend('00000000-0000-0000-0000-0000000b1001', 'hba1c', 'ALL'))::int,
  0,
  'physician_a gets no trend points for org B patient b1001'
);

-- ---------------------------------------------------------------------------
-- care_coordinator_a (same org): also gets the list + detail + trend.
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2'); -- care_coordinator_a
select isnt(
  (select public.open_patient_detail('00000000-0000-0000-0000-0000000a1001')),
  null,
  'care_coordinator_a can open a1001 detail'
);
select is(
  (select count(*) from public.patient_trend('00000000-0000-0000-0000-0000000a1001', 'hba1c', 'ALL'))::int,
  1,
  'care_coordinator_a gets trend points for a1001'
);

-- ---------------------------------------------------------------------------
-- read_only_a (Leo ruling, fix round 28 Oct): may view own-clinic list,
-- detail and trends, every open audited, but no actions. Org B stays
-- invisible everywhere, identical to every other role. Write/action RPCs and
-- direct table writes are refused.
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2'); -- read_only_a
select is(
  (select count(*) from public.physician_patient_roster(null, 'all', 'recent', 50, 0)
    where patient_id = '00000000-0000-0000-0000-0000000a1001')::int,
  1,
  'read_only_a CAN see the roster row for a1001'
);
select is(
  (select count(*) from public.lab_results where patient_id = '00000000-0000-0000-0000-0000000a1001')::int,
  1,
  'read_only_a sees a1001 lab_results (own clinic)'
);
select isnt(
  (select public.open_patient_detail('00000000-0000-0000-0000-0000000a1001')),
  null,
  'read_only_a can open a1001 detail (own clinic)'
);
select is(
  (select count(*)::int from jsonb_object_keys(
     public.open_patient_detail('00000000-0000-0000-0000-0000000a1001')) k
   where k not in ('patient_id', 'display_name', 'mrn', 'sex', 'birth_date', 'program_started_on', 'last_activity_at', 'treatment')),
  0,
  'read_only_a detail payload has only the whitelisted keys'
);
select is(
  (select count(*) from public.patient_trend('00000000-0000-0000-0000-0000000a1001', 'hba1c', 'ALL'))::int,
  1,
  'read_only_a gets trend points for a1001'
);
select is(
  (select count(*) from public.patient_latest_results('00000000-0000-0000-0000-0000000a1001'))::int,
  1,
  'read_only_a gets latest results for a1001'
);

-- ----- org B stays invisible to read_only_a, same as every other role -----
select is(
  (select count(*) from public.physician_patient_roster(null, 'all', 'recent', 50, 0)
    where patient_id = '00000000-0000-0000-0000-0000000b1001')::int,
  0,
  'read_only_a roster never includes org B patient b1001'
);
select is(
  (select public.open_patient_detail('00000000-0000-0000-0000-0000000b1001')),
  null,
  'read_only_a opening org B patient returns not-found (null)'
);
select is(
  (select count(*) from public.patient_trend('00000000-0000-0000-0000-0000000b1001', 'hba1c', 'ALL'))::int,
  0,
  'read_only_a gets no trend points for org B patient b1001'
);
select is(
  (select count(*) from public.patient_latest_results('00000000-0000-0000-0000-0000000b1001'))::int,
  0,
  'read_only_a gets no latest results for org B patient b1001'
);
select is(
  (select count(*) from public.lab_results where patient_id = '00000000-0000-0000-0000-0000000b1001')::int,
  0,
  'read_only_a sees no org B lab_results'
);
select is(
  (select count(*) from public.patient_treatments where patient_id = '00000000-0000-0000-0000-0000000b1001')::int,
  0,
  'read_only_a sees no org B patient_treatments'
);

-- ----- read_only_a is refused every write/action RPC -----
select throws_ok(
  $$ select public.flag_lab_report_needs_review('00000000-0000-0000-0000-00000015a301') $$,
  '42501',
  'not authorized',
  'read_only_a is refused flag_lab_report_needs_review'
);
select throws_ok(
  $$ select public.create_patient_record('00000000-0000-0000-0000-0000000a1001') $$,
  '42501',
  'not authorized',
  'read_only_a is refused create_patient_record'
);
select throws_ok(
  $$ select public.change_member_role('00000000-0000-0000-0000-0000000a0002', 'read_only') $$,
  '42501',
  'not authorized',
  'read_only_a is refused change_member_role'
);
select throws_ok(
  $$ select public.request_mfa_reset('00000000-0000-0000-0000-0000000a0002') $$,
  '42501',
  'not authorized',
  'read_only_a is refused request_mfa_reset'
);

-- ----- direct table writes are refused (no insert/update/delete grant) -----
select throws_ok(
  $$ insert into public.lab_results (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value, unit, status, taken_at)
     values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000015a301', 'hba1c', 'HbA1c', 9.9, '%', 'within_range', now()) $$,
  '42501', null,
  'read_only_a is refused a direct INSERT on lab_results'
);
select throws_ok(
  $$ update public.lab_results set value = 1.0 where patient_id = '00000000-0000-0000-0000-0000000a1001' $$,
  '42501', null,
  'read_only_a is refused a direct UPDATE on lab_results'
);
select throws_ok(
  $$ delete from public.patient_treatments where patient_id = '00000000-0000-0000-0000-0000000a1001' $$,
  '42501', null,
  'read_only_a is refused a direct DELETE on patient_treatments'
);
select throws_ok(
  $$ update public.patient_roster_meta set open_questions = 99 where patient_id = '00000000-0000-0000-0000-0000000a1001' $$,
  '42501', null,
  'read_only_a is refused a direct UPDATE on patient_roster_meta'
);

-- ---------------------------------------------------------------------------
-- physician_b (other clinic): no visibility into org A anywhere.
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2'); -- physician_b
select is(
  (select count(*) from public.lab_results where patient_id = '00000000-0000-0000-0000-0000000a1001')::int,
  0,
  'physician_b cannot direct-select a1001 lab_results'
);
select is(
  (select public.open_patient_detail('00000000-0000-0000-0000-0000000a1001')),
  null,
  'physician_b opening a1001 detail returns not-found (null), same as unknown'
);
select is(
  (select count(*) from public.patient_trend('00000000-0000-0000-0000-0000000a1001', 'hba1c', 'ALL'))::int,
  0,
  'physician_b gets no trend points for org A patient a1001'
);

select * from finish();
rollback;
