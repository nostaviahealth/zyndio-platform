-- TC-015 LOCAL-ONLY perf seed: 5,000 fictional patients in one org, for the
-- roster / chip-count query-plan evidence at the card-item-7 target scale. NOT
-- a migration - this never reaches production. Idempotent: stable identity rows
-- use ON CONFLICT DO NOTHING; the clinical rows are deleted-then-reinserted for
-- the perf org each run.
--
-- Same shape as perf_500_patients.sql (every lab state the UI renders:
-- needs-review, unmapped Lp-PLA2, corrected "was x", no-range, single-result,
-- identity-hold), scaled 10x. Two deltas vs the 500 seed:
--   * generate_series(1, 5000) everywhere;
--   * the MRN pad widens to lpad(n, 5, '0') - 'ZP-1' || lpad(n,4,'0') overflows
--     past 9999, so 'ZP-1' || lpad(n,5,'0') (ZP-100001 .. ZP-105000).
-- Ends by rebuilding patient_roster_summary (the triggers already maintained it
-- row-by-row during the inserts; refresh_roster_summary_all() guarantees a
-- clean, consistent rollup) and ANALYZE so the planner has fresh stats.
--
-- Everything is fictional. UUIDs are namespaced under 0000f015-* , far from the
-- 00000000-* pgTAP fixtures. Run with scripts/seed-perf-5000.sh.

-- Org + one physician to query as (JWT context: sub = this physician, aal2).
insert into public.organizations (id, name) values
  ('0000f015-0000-0000-0000-00000000000a', 'Perf Clinic (fictional)')
on conflict (id) do nothing;

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '0000f015-0000-0000-0000-0000000a0002',
  'authenticated', 'authenticated', 'perf-physician@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf', 4)),
  now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now()
) on conflict (id) do nothing;

insert into public.org_members (user_id, org_id, role, status) values
  ('0000f015-0000-0000-0000-0000000a0002', '0000f015-0000-0000-0000-00000000000a', 'physician', 'active')
on conflict (user_id) do nothing;

-- 5,000 patient auth.users + patients + roster meta (stable; idempotent).
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
select
  '00000000-0000-0000-0000-000000000000',
  ('0000f015-0000-0000-0001-' || lpad(n::text, 12, '0'))::uuid,
  'authenticated', 'authenticated', 'perf-patient-' || n || '@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf', 4)),
  now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now()
from generate_series(1, 5000) n
on conflict (id) do nothing;

insert into public.patients (id, org_id, display_name, mrn)
select
  ('0000f015-0000-0000-0001-' || lpad(n::text, 12, '0'))::uuid,
  '0000f015-0000-0000-0000-00000000000a',
  'Fictional Perf Patient ' || n,
  'ZP-1' || lpad(n::text, 5, '0')
from generate_series(1, 5000) n
on conflict (id) do nothing;

insert into public.patient_roster_meta (patient_id, org_id, sex, birth_date, program_started_on, last_activity_at, open_questions)
select
  ('0000f015-0000-0000-0001-' || lpad(n::text, 12, '0'))::uuid,
  '0000f015-0000-0000-0000-00000000000a',
  case when n % 2 = 0 then 'F' else 'M' end,
  (date '1950-01-01' + (n * 23) % 20000),
  (date '2026-01-01' + (n % 300)),
  now() - (n * interval '37 minutes'),   -- spread activity so the recent sort is non-trivial
  case when n % 11 = 0 then 1 + (n % 3) else 0 end
from generate_series(1, 5000) n
on conflict (patient_id) do nothing;

-- Treatment context for ~half the patients (POR-07; no dose, ever).
delete from public.patient_treatments where org_id = '0000f015-0000-0000-0000-00000000000a';
insert into public.patient_treatments (org_id, patient_id, name, started_on, status, source)
select
  '0000f015-0000-0000-0000-00000000000a',
  ('0000f015-0000-0000-0001-' || lpad(n::text, 12, '0'))::uuid,
  'Example GLP-1 medication (fictional)',
  (date '2026-01-01' + (n % 300)),
  'Active',
  'Zyndio record, Oct 20, 2026'
from generate_series(1, 5000) n
where n % 2 = 0;

-- Reports (cascades to lab_results on delete): one primary per patient, plus an
-- identity-hold report for every 7th patient. Delete-then-insert for the org.
delete from public.lab_reports where org_id = '0000f015-0000-0000-0000-00000000000a';

insert into public.lab_reports (id, org_id, patient_id, report_type, data, identity_hold)
select
  ('0000f015-0000-0000-0002-' || lpad((n * 10 + 1)::text, 12, '0'))::uuid,
  '0000f015-0000-0000-0000-00000000000a',
  ('0000f015-0000-0000-0001-' || lpad(n::text, 12, '0'))::uuid,
  'metabolic_panel', '{}', false
from generate_series(1, 5000) n;

insert into public.lab_reports (id, org_id, patient_id, report_type, data, identity_hold)
select
  ('0000f015-0000-0000-0002-' || lpad((n * 10 + 2)::text, 12, '0'))::uuid,
  '0000f015-0000-0000-0000-00000000000a',
  ('0000f015-0000-0000-0001-' || lpad(n::text, 12, '0'))::uuid,
  'metabolic_panel', '{}', true
from generate_series(1, 5000) n
where n % 7 = 0;

-- HbA1c series on the primary report. Single-result patients (n % 9 = 0) get
-- one point; everyone else gets 5 over ~14 months. n % 5 = 0 carries a
-- correction ("was 5.9"); n % 4 = 0 has no reference range (status no_range).
insert into public.lab_results
  (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value, original_value, unit, status, is_unmapped, range_low, range_high, taken_at)
select
  '0000f015-0000-0000-0000-00000000000a',
  ('0000f015-0000-0000-0001-' || lpad(n::text, 12, '0'))::uuid,
  ('0000f015-0000-0000-0002-' || lpad((n * 10 + 1)::text, 12, '0'))::uuid,
  'hba1c', 'HbA1c',
  round((5.2 + ((n + j) % 15) * 0.1)::numeric, 1),
  case when n % 5 = 0 and j = 1 then 5.9 end,
  '%',
  case when n % 4 = 0 then 'no_range' else 'within_range' end,
  false,
  case when n % 4 = 0 then null else 4.0 end,
  case when n % 4 = 0 then null else 5.7 end,
  now() - (j * interval '85 days')
from generate_series(1, 5000) n
cross join lateral generate_series(0, case when n % 9 = 0 then 0 else 4 end) j;

-- Needs-review hsCRP (every 6th patient): appears in the latest list, never in trend.
insert into public.lab_results
  (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value, unit, status, taken_at)
select
  '0000f015-0000-0000-0000-00000000000a',
  ('0000f015-0000-0000-0001-' || lpad(n::text, 12, '0'))::uuid,
  ('0000f015-0000-0000-0002-' || lpad((n * 10 + 1)::text, 12, '0'))::uuid,
  'hscrp', 'hsCRP', 1.4 + (n % 5) * 0.3, 'mg/L', 'needs_review', now() - interval '12 days'
from generate_series(1, 5000) n
where n % 6 = 0;

-- Unmapped Lp-PLA2 (every 8th patient): "Not used in trends".
insert into public.lab_results
  (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value, unit, status, is_unmapped, taken_at)
select
  '0000f015-0000-0000-0000-00000000000a',
  ('0000f015-0000-0000-0001-' || lpad(n::text, 12, '0'))::uuid,
  ('0000f015-0000-0000-0002-' || lpad((n * 10 + 1)::text, 12, '0'))::uuid,
  'lp_pla2', 'Lp-PLA2', 150 + (n % 40), 'nmol/min/mL', 'no_range', true, now() - interval '12 days'
from generate_series(1, 5000) n
where n % 8 = 0;

-- Identity-hold HbA1c point (the 9.9 outlier) on the hold report: must stay out
-- of trends and the latest list for every 7th patient.
insert into public.lab_results
  (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value, unit, status, range_low, range_high, taken_at)
select
  '0000f015-0000-0000-0000-00000000000a',
  ('0000f015-0000-0000-0001-' || lpad(n::text, 12, '0'))::uuid,
  ('0000f015-0000-0000-0002-' || lpad((n * 10 + 2)::text, 12, '0'))::uuid,
  'hba1c', 'HbA1c', 9.9, '%', 'within_range', 4.0, 5.7, now() - interval '3 days'
from generate_series(1, 5000) n
where n % 7 = 0;

-- Rebuild the per-patient rollup for a clean, consistent summary and refresh
-- planner stats on every table the roster touches.
select public.refresh_roster_summary_all();

analyze public.lab_results;
analyze public.lab_reports;
analyze public.patient_roster_meta;
analyze public.patient_treatments;
analyze public.patients;
analyze public.patient_roster_summary;
