-- TC-015 fix round (card item 7, Leo C3): the roster must sort + paginate the
-- page BEFORE summarising, and meet < 200 ms at 5,000 patients, with EXACT
-- semantic parity vs the pre-perf definition. Chosen design (B): a per-patient
-- public.patient_roster_summary table, maintained by triggers, that
-- physician_roster_base() left-joins instead of recomputing a per-result
-- LATERAL over lab_results for every org patient.
--
-- This file is the acceptance test for that redesign. It proves, in one
-- transaction with a frozen copy of the CURRENT (pre-summary) roster logic as
-- the oracle:
--   1. structural - the summary table, its refresh functions and the three
--      maintenance triggers exist (these FAIL on the current code: fail-first);
--   2. parity - the new roster returns exactly the same rows / flags / order /
--      total as the oracle across every filter, sort, search and page, for
--      physician AND read_only (read_only now has own-clinic Labs access, so
--      its flags must be REAL, not degraded), plus chip_counts parity;
--   3. per-event drift - a lab/treatment/identity-hold mutation is reflected in
--      the roster (post-fix this exercises the maintenance triggers).
--
-- Fixtures + the oracle functions are built inside this file's own transaction
-- (as the pg_prove superuser, before authenticate_as) under TC-015-namespaced
-- UUIDs (…720…), and rolled back at the end, so nothing leaks into the shared
-- 000_fixtures state or other test files.
begin;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);

-- ---------------------------------------------------------------------------
-- auth.users for every fixture patient (patients.id -> auth.users.id).
-- ---------------------------------------------------------------------------
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
select
  '00000000-0000-0000-0000-000000000000', u.id,
  'authenticated', 'authenticated', 'perf-parity-' || u.id || '@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf', 4)),
  now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now()
from (values
  ('00000000-0000-0000-0000-000000720201'::uuid),
  ('00000000-0000-0000-0000-000000720202'::uuid),
  ('00000000-0000-0000-0000-000000720203'::uuid),
  ('00000000-0000-0000-0000-000000720204'::uuid),
  ('00000000-0000-0000-0000-000000720205'::uuid),
  ('00000000-0000-0000-0000-000000720206'::uuid),
  ('00000000-0000-0000-0000-000000720207'::uuid),
  ('00000000-0000-0000-0000-000000720208'::uuid),
  ('00000000-0000-0000-0000-000000720b01'::uuid),
  ('00000000-0000-0000-0000-000000720d01'::uuid),
  ('00000000-0000-0000-0000-000000720d02'::uuid),
  ('00000000-0000-0000-0000-000000720d03'::uuid),
  ('00000000-0000-0000-0000-000000720d04'::uuid),
  ('00000000-0000-0000-0000-000000720d05'::uuid),
  ('00000000-0000-0000-0000-000000720d06'::uuid)
) as u(id);

-- ---------------------------------------------------------------------------
-- 8 org-A parity patients covering every flag combination + 1 org-B anchor.
-- last_activity_at is spread (one NULL) so recent/oldest sorts + NULLS LAST are
-- non-trivial; display names are distinct so tie-breaks are deterministic.
-- ---------------------------------------------------------------------------
insert into public.patients (id, org_id, display_name, mrn) values
  ('00000000-0000-0000-0000-000000720201', '00000000-0000-0000-0000-00000000000a', 'Parity Alpha',   'ZP-7201'),
  ('00000000-0000-0000-0000-000000720202', '00000000-0000-0000-0000-00000000000a', 'Parity Bravo',   'ZP-7202'),
  ('00000000-0000-0000-0000-000000720203', '00000000-0000-0000-0000-00000000000a', 'Parity Charlie', 'ZP-7203'),
  ('00000000-0000-0000-0000-000000720204', '00000000-0000-0000-0000-00000000000a', 'Parity Delta',   'ZP-7204'),
  ('00000000-0000-0000-0000-000000720205', '00000000-0000-0000-0000-00000000000a', 'Parity Echo',    'ZP-7205'),
  ('00000000-0000-0000-0000-000000720206', '00000000-0000-0000-0000-00000000000a', 'Parity Foxtrot', 'ZP-7206'),
  ('00000000-0000-0000-0000-000000720207', '00000000-0000-0000-0000-00000000000a', 'Parity Golf',    'ZP-7207'),
  ('00000000-0000-0000-0000-000000720208', '00000000-0000-0000-0000-00000000000a', 'Parity Hotel',   'ZP-7208'),
  ('00000000-0000-0000-0000-000000720b01', '00000000-0000-0000-0000-00000000000b', 'Parity OrgB',    'ZP-72B1');

insert into public.patient_roster_meta
  (patient_id, org_id, sex, birth_date, program_started_on, last_activity_at, open_questions) values
  ('00000000-0000-0000-0000-000000720201', '00000000-0000-0000-0000-00000000000a', 'F', date '1980-01-01', date '2026-01-01', now() - interval '1 hour',  0),
  ('00000000-0000-0000-0000-000000720202', '00000000-0000-0000-0000-00000000000a', 'M', date '1981-02-02', date '2026-02-01', now() - interval '2 hour',  0),
  ('00000000-0000-0000-0000-000000720203', '00000000-0000-0000-0000-00000000000a', 'F', date '1982-03-03', date '2026-03-01', now() - interval '3 hour',  0),
  ('00000000-0000-0000-0000-000000720204', '00000000-0000-0000-0000-00000000000a', 'M', date '1983-04-04', date '2026-04-01', now() - interval '4 hour',  0),
  ('00000000-0000-0000-0000-000000720205', '00000000-0000-0000-0000-00000000000a', 'F', date '1984-05-05', date '2026-05-01', null,                      0),
  ('00000000-0000-0000-0000-000000720206', '00000000-0000-0000-0000-00000000000a', 'M', date '1985-06-06', date '2026-06-01', now() - interval '6 hour',  2),
  ('00000000-0000-0000-0000-000000720207', '00000000-0000-0000-0000-00000000000a', 'F', date '1986-07-07', date '2026-07-01', now() - interval '7 hour',  0),
  ('00000000-0000-0000-0000-000000720208', '00000000-0000-0000-0000-00000000000a', 'M', date '1987-08-08', date '2026-08-01', now() - interval '8 hour',  1),
  ('00000000-0000-0000-0000-000000720b01', '00000000-0000-0000-0000-00000000000b', 'F', date '1988-09-09', date '2026-09-01', now() - interval '9 hour',  0);

-- one non-hold report per org-A patient with labs (+ org B), plus a hold report
-- for Delta (her only result lives on the hold report).
insert into public.lab_reports (id, org_id, patient_id, report_type, data, identity_hold) values
  ('00000000-0000-0000-0000-0000720a0201', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720201', 'metabolic_panel', '{}', false),
  ('00000000-0000-0000-0000-0000720a0202', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720202', 'metabolic_panel', '{}', false),
  ('00000000-0000-0000-0000-0000720a0203', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720203', 'metabolic_panel', '{}', false),
  ('00000000-0000-0000-0000-0000720a0204', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720204', 'metabolic_panel', '{}', true),
  ('00000000-0000-0000-0000-0000720a0206', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720206', 'metabolic_panel', '{}', false),
  ('00000000-0000-0000-0000-0000720a0207', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720207', 'metabolic_panel', '{}', false),
  ('00000000-0000-0000-0000-0000720a0208', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720208', 'metabolic_panel', '{}', false),
  ('00000000-0000-0000-0000-0000720b0201', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000720b01', 'metabolic_panel', '{}', false);

insert into public.lab_results
  (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value, unit, status, taken_at) values
  -- Alpha: within_range only -> no attention flag
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720201', '00000000-0000-0000-0000-0000720a0201', 'hba1c', 'HbA1c', 5.4, '%', 'within_range', now() - interval '10 days'),
  -- Bravo: outside_range (+ treatment) -> outside_range, clinical_context
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720202', '00000000-0000-0000-0000-0000720a0202', 'hba1c', 'HbA1c', 7.2, '%', 'outside_range', now() - interval '11 days'),
  -- Charlie: needs_review -> needs_review
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720203', '00000000-0000-0000-0000-0000720a0203', 'hscrp', 'hsCRP', 1.7, 'mg/L', 'needs_review', now() - interval '12 days'),
  -- Delta: only an identity-hold result -> identity_hold + missing_labs
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720204', '00000000-0000-0000-0000-0000720a0204', 'hba1c', 'HbA1c', 9.9, '%', 'within_range', now() - interval '13 days'),
  -- Echo: NO labs -> missing_labs (no result rows)
  -- Foxtrot: within_range + open_questions=2 -> question_waiting
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720206', '00000000-0000-0000-0000-0000720a0206', 'hba1c', 'HbA1c', 5.6, '%', 'within_range', now() - interval '14 days'),
  -- Golf: within_range + treatment -> clinical_context
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720207', '00000000-0000-0000-0000-0000720a0207', 'hba1c', 'HbA1c', 5.5, '%', 'within_range', now() - interval '15 days'),
  -- Hotel: outside_range + needs_review + open_questions=1
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720208', '00000000-0000-0000-0000-0000720a0208', 'hba1c', 'HbA1c', 8.1, '%', 'outside_range', now() - interval '16 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720208', '00000000-0000-0000-0000-0000720a0208', 'hscrp', 'hsCRP', 2.0, 'mg/L', 'needs_review', now() - interval '16 days'),
  -- org B anchor
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000720b01', '00000000-0000-0000-0000-0000720b0201', 'hba1c', 'HbA1c', 6.0, '%', 'within_range', now() - interval '17 days');

insert into public.patient_treatments (org_id, patient_id, name, started_on, status, source) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720202', 'Example GLP-1 medication (fictional)', date '2026-02-02', 'Active', 'Zyndio record'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720207', 'Example statin (fictional)',          date '2026-07-02', 'Active', 'Zyndio record');

-- ---------------------------------------------------------------------------
-- Frozen oracle: a verbatim copy of the CURRENT (pre-summary) roster logic
-- (physician_roster_base / physician_patient_roster / physician_roster_chip_counts
-- as of migration 20261028154000). SECURITY INVOKER so RLS applies with the
-- caller's rights exactly as the shipped functions do. This is the baseline the
-- redesigned functions must match row-for-row.
-- ---------------------------------------------------------------------------
create function public._tc720_oracle_base()
returns table (
  patient_id uuid, display_name text, mrn text, sex text, birth_date date,
  program_started_on date, latest_lab_at timestamptz, last_activity_at timestamptz,
  open_questions int, flags text[]
)
language sql stable security invoker
set search_path = pg_catalog, public
as $$
  select
    p.id, p.display_name, p.mrn, m.sex, m.birth_date, m.program_started_on,
    la.latest_lab_at, m.last_activity_at, coalesce(m.open_questions, 0),
    array_remove(array[
      case when tr.has_treatment then 'clinical_context' end,
      case when la.has_outside_range then 'outside_range' end,
      case when la.has_needs_review then 'needs_review' end,
      case when la.has_identity_hold then 'identity_hold' end,
      case when not coalesce(la.has_any_labs, false) then 'missing_labs' end,
      case when coalesce(m.open_questions, 0) > 0 then 'question_waiting' end
    ], null)
  from public.patients p
  left join public.patient_roster_meta m on m.patient_id = p.id
  left join lateral (
    select
      max(lr.taken_at) filter (where not public.lab_report_held(lr.lab_report_id)) as latest_lab_at,
      bool_or(lr.status = 'outside_range' and not public.lab_report_held(lr.lab_report_id)) as has_outside_range,
      bool_or(lr.status = 'needs_review' and not public.lab_report_held(lr.lab_report_id)) as has_needs_review,
      bool_or(public.lab_report_held(lr.lab_report_id)) as has_identity_hold,
      count(lr.id) filter (where not public.lab_report_held(lr.lab_report_id)) > 0 as has_any_labs
    from public.lab_results lr
    where lr.patient_id = p.id
  ) la on true
  left join lateral (
    select true as has_treatment
    from public.patient_treatments t
    where t.patient_id = p.id
    limit 1
  ) tr on true
  where p.org_id = public.current_org_id();
$$;

create function public._tc720_oracle_roster(
  p_search text default null, p_filter text default 'all',
  p_sort text default 'recent', p_limit int default 50, p_offset int default 0
)
returns table (
  patient_id uuid, display_name text, mrn text, sex text, birth_date date,
  program_started_on date, latest_lab_at timestamptz, last_activity_at timestamptz,
  open_questions int, flags text[], total_count bigint
)
language sql stable security invoker
set search_path = pg_catalog, public
as $$
  with filtered as (
    select r.* from public._tc720_oracle_base() r
    where
      case coalesce(p_filter, 'all')
        when 'flagged' then r.flags && array['outside_range', 'needs_review', 'identity_hold', 'question_waiting']
        when 'missing_labs' then 'missing_labs' = any(r.flags)
        when 'questions_waiting' then 'question_waiting' = any(r.flags)
        else true
      end
      and (
        p_search is null or p_search = ''
        or r.display_name ilike '%' || p_search || '%'
        or r.mrn ilike '%' || p_search || '%'
      )
  )
  select f.patient_id, f.display_name, f.mrn, f.sex, f.birth_date, f.program_started_on,
    f.latest_lab_at, f.last_activity_at, f.open_questions, f.flags, count(*) over () as total_count
  from filtered f
  order by
    case when coalesce(p_filter, 'all') = 'questions_waiting' then f.last_activity_at end asc nulls last,
    case when coalesce(p_filter, 'all') <> 'questions_waiting' then f.last_activity_at end desc nulls last,
    f.display_name asc
  limit least(coalesce(p_limit, 50), 100)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

create function public._tc720_oracle_chips()
returns table (
  all_count bigint, flagged_count bigint, missing_labs_count bigint, questions_waiting_count bigint
)
language sql stable security invoker
set search_path = pg_catalog, public
as $$
  select count(*),
    count(*) filter (where r.flags && array['outside_range', 'needs_review', 'identity_hold', 'question_waiting']),
    count(*) filter (where 'missing_labs' = any(r.flags)),
    count(*) filter (where 'question_waiting' = any(r.flags))
  from public._tc720_oracle_base() r;
$$;

-- Query-string builders so new/oracle parity pairs stay byte-identical in shape.
create function public._tc720_new_sql(p_search text, p_filter text, p_sort text, p_limit int, p_offset int)
returns text language sql immutable as $$
  select format(
    'select patient_id, display_name, mrn, sex, birth_date, program_started_on, latest_lab_at, last_activity_at, open_questions, flags, total_count from public.physician_patient_roster(%L,%L,%L,%s,%s)',
    p_search, p_filter, p_sort, p_limit, p_offset);
$$;
create function public._tc720_ora_sql(p_search text, p_filter text, p_sort text, p_limit int, p_offset int)
returns text language sql immutable as $$
  select format(
    'select patient_id, display_name, mrn, sex, birth_date, program_started_on, latest_lab_at, last_activity_at, open_questions, flags, total_count from public._tc720_oracle_roster(%L,%L,%L,%s,%s)',
    p_search, p_filter, p_sort, p_limit, p_offset);
$$;

-- one patient's flags as the current caller
create function public._tc720_flags(p uuid) returns text[]
language sql stable security invoker set search_path = pg_catalog, public as $$
  select flags from public.physician_roster_base() where patient_id = p;
$$;
-- TC-040 (#34 M1): functions postgres creates no longer get PUBLIC EXECUTE by
-- default, so test-only helpers called after a role switch are granted explicitly.
grant execute on function public._tc720_oracle_base(), public._tc720_oracle_roster(text, text, text, integer, integer),
  public._tc720_oracle_chips(), public._tc720_new_sql(text, text, text, integer, integer),
  public._tc720_ora_sql(text, text, text, integer, integer), public._tc720_flags(uuid) to authenticated;

-- ===========================================================================
-- 1. Structural assertions (FAIL-FIRST: these fail on the current code).
-- ===========================================================================
select has_table('public', 'patient_roster_summary',
  'patient_roster_summary table exists (per-patient roster rollup)');
select has_column('public', 'patient_roster_summary', 'has_outside_range',
  'patient_roster_summary.has_outside_range exists');
select has_column('public', 'patient_roster_summary', 'has_identity_hold',
  'patient_roster_summary.has_identity_hold exists');
select has_column('public', 'patient_roster_summary', 'has_any_labs',
  'patient_roster_summary.has_any_labs exists');
select has_column('public', 'patient_roster_summary', 'has_treatment',
  'patient_roster_summary.has_treatment exists');
select has_function('public', 'refresh_roster_summary', array['uuid'],
  'refresh_roster_summary(uuid) recompute function exists');
select has_function('public', 'refresh_roster_summary_all', array[]::text[],
  'refresh_roster_summary_all() batch builder exists');
select has_trigger('public', 'lab_results', 'trg_lab_results_roster_summary',
  'lab_results maintains the roster summary via trigger');
select has_trigger('public', 'lab_reports', 'trg_lab_reports_roster_summary',
  'lab_reports identity_hold toggle maintains the roster summary via trigger');
select has_trigger('public', 'patient_treatments', 'trg_patient_treatments_roster_summary',
  'patient_treatments maintains the roster summary via trigger');

-- ===========================================================================
-- 2. Parity as physician_a: new roster == frozen oracle for every filter /
--    sort / search / page, plus chip counts.
-- ===========================================================================
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a

select results_eq(public._tc720_new_sql(null, 'all', 'recent', 50, 0),
                  public._tc720_ora_sql(null, 'all', 'recent', 50, 0),
  'parity physician: all / full page');
select results_eq(public._tc720_new_sql(null, 'all', 'recent', 3, 0),
                  public._tc720_ora_sql(null, 'all', 'recent', 3, 0),
  'parity physician: all / page 1 (limit 3)');
select results_eq(public._tc720_new_sql(null, 'all', 'recent', 3, 3),
                  public._tc720_ora_sql(null, 'all', 'recent', 3, 3),
  'parity physician: all / page 2 (limit 3 offset 3)');
select results_eq(public._tc720_new_sql(null, 'all', 'recent', 3, 6),
                  public._tc720_ora_sql(null, 'all', 'recent', 3, 6),
  'parity physician: all / page 3 (limit 3 offset 6)');
select results_eq(public._tc720_new_sql(null, 'flagged', 'recent', 50, 0),
                  public._tc720_ora_sql(null, 'flagged', 'recent', 50, 0),
  'parity physician: flagged filter');
select results_eq(public._tc720_new_sql(null, 'missing_labs', 'recent', 50, 0),
                  public._tc720_ora_sql(null, 'missing_labs', 'recent', 50, 0),
  'parity physician: missing_labs filter');
select results_eq(public._tc720_new_sql(null, 'questions_waiting', 'recent', 50, 0),
                  public._tc720_ora_sql(null, 'questions_waiting', 'recent', 50, 0),
  'parity physician: questions_waiting filter (oldest-first sort)');
select results_eq(public._tc720_new_sql('Parity', 'all', 'recent', 50, 0),
                  public._tc720_ora_sql('Parity', 'all', 'recent', 50, 0),
  'parity physician: name search');
select results_eq(public._tc720_new_sql('ZP-720', 'all', 'recent', 50, 0),
                  public._tc720_ora_sql('ZP-720', 'all', 'recent', 50, 0),
  'parity physician: MRN search');
select results_eq(public._tc720_new_sql('Delta', 'all', 'recent', 50, 0),
                  public._tc720_ora_sql('Delta', 'all', 'recent', 50, 0),
  'parity physician: single-name search');

select is(
  (select row(all_count, flagged_count, missing_labs_count, questions_waiting_count)::text
     from public.physician_roster_chip_counts()),
  (select row(all_count, flagged_count, missing_labs_count, questions_waiting_count)::text
     from public._tc720_oracle_chips()),
  'parity physician: chip counts match the oracle'
);

-- ===========================================================================
-- 3. Parity as read_only_a: own-clinic Labs access means flags are REAL
--    (identical to physician), not degraded to missing_labs.
-- ===========================================================================
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2'); -- read_only_a

select results_eq(public._tc720_new_sql(null, 'all', 'recent', 50, 0),
                  public._tc720_ora_sql(null, 'all', 'recent', 50, 0),
  'parity read_only: all / full page (flags are real, not degraded)');
select results_eq(public._tc720_new_sql(null, 'flagged', 'recent', 50, 0),
                  public._tc720_ora_sql(null, 'flagged', 'recent', 50, 0),
  'parity read_only: flagged filter');
select results_eq(public._tc720_new_sql(null, 'missing_labs', 'recent', 50, 0),
                  public._tc720_ora_sql(null, 'missing_labs', 'recent', 50, 0),
  'parity read_only: missing_labs filter');
select is(
  (select row(all_count, flagged_count, missing_labs_count, questions_waiting_count)::text
     from public.physician_roster_chip_counts()),
  (select row(all_count, flagged_count, missing_labs_count, questions_waiting_count)::text
     from public._tc720_oracle_chips()),
  'parity read_only: chip counts match the oracle'
);
select is(
  (select count(*) from public.physician_patient_roster(null, 'all', 'recent', 50, 0)
    where patient_id = '00000000-0000-0000-0000-000000720b01')::int,
  0,
  'read_only roster never includes the org-B patient'
);

-- ===========================================================================
-- 4. Per-event drift: a mutation must be reflected in the roster. Post-fix the
--    roster reads the summary, so each of these exercises a maintenance trigger
--    (a stale/missing trigger fails these). Mutations run as the superuser
--    (reset role); reads run as physician_a.
-- ===========================================================================
reset role;
select set_config('request.jwt.claims', '', true);

insert into public.patients (id, org_id, display_name, mrn) values
  ('00000000-0000-0000-0000-000000720d01', '00000000-0000-0000-0000-00000000000a', 'Drift Delta-01', 'ZP-72D1'),
  ('00000000-0000-0000-0000-000000720d02', '00000000-0000-0000-0000-00000000000a', 'Drift Delta-02', 'ZP-72D2'),
  ('00000000-0000-0000-0000-000000720d03', '00000000-0000-0000-0000-00000000000a', 'Drift Delta-03', 'ZP-72D3'),
  ('00000000-0000-0000-0000-000000720d04', '00000000-0000-0000-0000-00000000000a', 'Drift Delta-04', 'ZP-72D4'),
  ('00000000-0000-0000-0000-000000720d05', '00000000-0000-0000-0000-00000000000a', 'Drift Delta-05', 'ZP-72D5'),
  ('00000000-0000-0000-0000-000000720d06', '00000000-0000-0000-0000-00000000000a', 'Drift Delta-06', 'ZP-72D6');

insert into public.lab_reports (id, org_id, patient_id, report_type, data, identity_hold) values
  ('00000000-0000-0000-0000-0000720d0202', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720d02', 'metabolic_panel', '{}', false),
  ('00000000-0000-0000-0000-0000720d0203', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720d03', 'metabolic_panel', '{}', false),
  ('00000000-0000-0000-0000-0000720d0204', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720d04', 'metabolic_panel', '{}', false);

insert into public.patient_roster_meta (patient_id, org_id, last_activity_at, open_questions) values
  ('00000000-0000-0000-0000-000000720d01', '00000000-0000-0000-0000-00000000000a', now(), 0),
  ('00000000-0000-0000-0000-000000720d02', '00000000-0000-0000-0000-00000000000a', now(), 0),
  ('00000000-0000-0000-0000-000000720d03', '00000000-0000-0000-0000-00000000000a', now(), 0),
  ('00000000-0000-0000-0000-000000720d04', '00000000-0000-0000-0000-00000000000a', now(), 0),
  ('00000000-0000-0000-0000-000000720d05', '00000000-0000-0000-0000-00000000000a', now(), 0),
  ('00000000-0000-0000-0000-000000720d06', '00000000-0000-0000-0000-00000000000a', now(), 0);

insert into public.lab_results (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value, unit, status, taken_at) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720d02', '00000000-0000-0000-0000-0000720d0202', 'hba1c', 'HbA1c', 5.4, '%', 'within_range', now() - interval '9 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720d03', '00000000-0000-0000-0000-0000720d0203', 'hba1c', 'HbA1c', 5.4, '%', 'within_range', now() - interval '9 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720d04', '00000000-0000-0000-0000-0000720d0204', 'hba1c', 'HbA1c', 5.4, '%', 'within_range', now() - interval '9 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720d04', '00000000-0000-0000-0000-0000720d0204', 'hba1c', 'HbA1c', 5.5, '%', 'within_range', now() - interval '8 days');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');

-- (a) d01 has no labs -> missing_labs present
select ok( 'missing_labs' = any(public._tc720_flags('00000000-0000-0000-0000-000000720d01')),
  'drift: patient with no labs starts flagged missing_labs');

-- (b) insert the first lab for d01 -> missing_labs clears
reset role; select set_config('request.jwt.claims', '', true);
insert into public.lab_reports (id, org_id, patient_id, report_type, data, identity_hold) values
  ('00000000-0000-0000-0000-0000720d0201', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720d01', 'metabolic_panel', '{}', false);
insert into public.lab_results (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value, unit, status, taken_at) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720d01', '00000000-0000-0000-0000-0000720d0201', 'hba1c', 'HbA1c', 5.3, '%', 'within_range', now() - interval '1 day');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select ok( not ('missing_labs' = any(public._tc720_flags('00000000-0000-0000-0000-000000720d01'))),
  'drift: inserting the first lab clears missing_labs');

-- (c) d02 gets an outside_range result -> outside_range flag appears
reset role; select set_config('request.jwt.claims', '', true);
insert into public.lab_results (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value, unit, status, taken_at) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720d02', '00000000-0000-0000-0000-0000720d0202', 'hba1c', 'HbA1c', 7.7, '%', 'outside_range', now() - interval '2 days');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select ok( 'outside_range' = any(public._tc720_flags('00000000-0000-0000-0000-000000720d02')),
  'drift: an outside_range result makes the patient flagged');

-- (d) toggle d03's report to identity_hold -> its only labs become held:
--     identity_hold + missing_labs appear; toggle back -> they clear.
reset role; select set_config('request.jwt.claims', '', true);
update public.lab_reports set identity_hold = true where id = '00000000-0000-0000-0000-0000720d0203';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select ok( 'identity_hold' = any(public._tc720_flags('00000000-0000-0000-0000-000000720d03'))
       and 'missing_labs' = any(public._tc720_flags('00000000-0000-0000-0000-000000720d03')),
  'drift: identity_hold toggle ON adds identity_hold and re-adds missing_labs');
reset role; select set_config('request.jwt.claims', '', true);
update public.lab_reports set identity_hold = false where id = '00000000-0000-0000-0000-0000720d0203';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select ok( not ('identity_hold' = any(public._tc720_flags('00000000-0000-0000-0000-000000720d03')))
       and not ('missing_labs' = any(public._tc720_flags('00000000-0000-0000-0000-000000720d03'))),
  'drift: identity_hold toggle OFF clears identity_hold and missing_labs');

-- (e) delete d04's results: still has labs after the first delete, missing_labs
--     only after the last.
reset role; select set_config('request.jwt.claims', '', true);
delete from public.lab_results where patient_id = '00000000-0000-0000-0000-000000720d04' and value = 5.5;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select ok( not ('missing_labs' = any(public._tc720_flags('00000000-0000-0000-0000-000000720d04'))),
  'drift: deleting one of two results does not yet trigger missing_labs');
reset role; select set_config('request.jwt.claims', '', true);
delete from public.lab_results where patient_id = '00000000-0000-0000-0000-000000720d04' and value = 5.4;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select ok( 'missing_labs' = any(public._tc720_flags('00000000-0000-0000-0000-000000720d04')),
  'drift: deleting the last result re-adds missing_labs');

-- (f) treatment insert -> clinical_context appears; delete -> clears.
reset role; select set_config('request.jwt.claims', '', true);
insert into public.patient_treatments (org_id, patient_id, name, started_on, status, source) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000720d05', 'Example GLP-1 medication (fictional)', date '2026-05-02', 'Active', 'Zyndio record');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select ok( 'clinical_context' = any(public._tc720_flags('00000000-0000-0000-0000-000000720d05')),
  'drift: inserting a treatment adds clinical_context');
reset role; select set_config('request.jwt.claims', '', true);
delete from public.patient_treatments where patient_id = '00000000-0000-0000-0000-000000720d05';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select ok( not ('clinical_context' = any(public._tc720_flags('00000000-0000-0000-0000-000000720d05'))),
  'drift: deleting the treatment clears clinical_context');

-- (g) open_questions 0 -> 2 -> 0 (lives on patient_roster_meta, read live).
reset role; select set_config('request.jwt.claims', '', true);
update public.patient_roster_meta set open_questions = 2 where patient_id = '00000000-0000-0000-0000-000000720d06';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select ok( 'question_waiting' = any(public._tc720_flags('00000000-0000-0000-0000-000000720d06')),
  'drift: open_questions > 0 adds question_waiting');
reset role; select set_config('request.jwt.claims', '', true);
update public.patient_roster_meta set open_questions = 0 where patient_id = '00000000-0000-0000-0000-000000720d06';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select ok( not ('question_waiting' = any(public._tc720_flags('00000000-0000-0000-0000-000000720d06'))),
  'drift: open_questions back to 0 clears question_waiting');

select * from finish();
rollback;
