-- TC-015 slice 1, fail-first trend / latest-results data rules (Leo ruling 5).
--
-- patient_trend excludes: status = 'needs_review', is_unmapped = true, and any
-- result whose lab_report has identity_hold = true. Corrected values keep
-- original_value ("was 2.4"). The period window (3M/6M/1Y/ALL, default 6M)
-- bounds taken_at. The latest-results data (Labs tab) ALSO excludes
-- identity-hold reports, but needs-review values DO appear there with their
-- status; unmapped/identity-hold never reach trend points.
--
-- Fixtures live in this transaction only, TC-015-namespaced, rolled back.
-- Expect FAIL until public.lab_results + patient_trend + patient_latest_results
-- land.
begin;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);

-- Visible report R1 and an identity-hold report R2 for org A patient a1001.
insert into public.lab_reports (id, org_id, patient_id, report_type, data, identity_hold) values
  ('00000000-0000-0000-0000-00000015a301', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'metabolic_panel', '{}', false),
  ('00000000-0000-0000-0000-00000015a302', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'metabolic_panel', '{}', true);

-- HbA1c series on the visible report: 4 valid points (one corrected, one old),
-- plus an identity-hold point that must never appear.
insert into public.lab_results
  (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value, original_value, unit, status, is_unmapped, range_low, range_high, taken_at) values
  -- valid HbA1c points on the visible report
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000015a301', 'hba1c', 'HbA1c', 5.5, null, '%', 'within_range', false, null, 5.7, now() - interval '20 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000015a301', 'hba1c', 'HbA1c', 5.4, 5.6, '%', 'within_range', false, null, 5.7, now() - interval '15 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000015a301', 'hba1c', 'HbA1c', 5.7, null, '%', 'within_range', false, null, 5.7, now() - interval '80 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000015a301', 'hba1c', 'HbA1c', 6.2, null, '%', 'baseline', false, null, 5.7, now() - interval '200 days'),
  -- identity-hold HbA1c point (most recent) - excluded from trend AND latest
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000015a302', 'hba1c', 'HbA1c', 9.9, null, '%', 'within_range', false, null, 5.7, now() - interval '5 days'),
  -- needs-review hsCRP: never in trend, but appears in latest with its status
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000015a301', 'hscrp', 'hsCRP', 1.7, null, 'mg/L', 'needs_review', false, null, null, now() - interval '10 days'),
  -- unmapped Lp-PLA2: never in trend
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000015a301', 'lp_pla2', 'Lp-PLA2', 171, null, 'nmol/min/mL', 'no_range', true, null, null, now() - interval '10 days');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a

-- ----- period window on the HbA1c trend -----
select is(
  (select count(*) from public.patient_trend('00000000-0000-0000-0000-0000000a1001', 'hba1c', 'ALL'))::int,
  4,
  'HbA1c trend ALL = 4 valid points (identity-hold 9.9 excluded)'
);
select is(
  (select count(*) from public.patient_trend('00000000-0000-0000-0000-0000000a1001', 'hba1c', '6M'))::int,
  3,
  'HbA1c trend 6M drops the 200-day-old baseline point'
);
select is(
  (select count(*) from public.patient_trend('00000000-0000-0000-0000-0000000a1001', 'hba1c'))::int,
  3,
  'HbA1c trend default period is 6M (3 points)'
);

-- ----- identity-hold result never in the trend -----
select is(
  (select count(*) from public.patient_trend('00000000-0000-0000-0000-0000000a1001', 'hba1c', 'ALL')
    where value = 9.9)::int,
  0,
  'identity-hold HbA1c value (9.9) is absent from the trend'
);

-- ----- corrected value keeps original_value -----
select is(
  (select original_value from public.patient_trend('00000000-0000-0000-0000-0000000a1001', 'hba1c', 'ALL')
    where value = 5.4),
  5.6::numeric,
  'corrected HbA1c point carries original_value 5.6 ("was 5.6")'
);

-- ----- needs-review value never in the trend -----
select is(
  (select count(*) from public.patient_trend('00000000-0000-0000-0000-0000000a1001', 'hscrp', 'ALL'))::int,
  0,
  'needs-review hsCRP is absent from the trend'
);

-- ----- unmapped value never in the trend -----
select is(
  (select count(*) from public.patient_trend('00000000-0000-0000-0000-0000000a1001', 'lp_pla2', 'ALL'))::int,
  0,
  'unmapped Lp-PLA2 is absent from the trend'
);

-- ----- latest-results data: excludes identity-hold, keeps needs-review -----
select is(
  (select value from public.patient_latest_results('00000000-0000-0000-0000-0000000a1001')
    where analyte_key = 'hba1c'),
  5.5::numeric,
  'latest HbA1c is the 20-day-old 5.5 (identity-hold 9.9 excluded from latest)'
);
select is(
  (select count(*) from public.patient_latest_results('00000000-0000-0000-0000-0000000a1001')
    where value = 9.9)::int,
  0,
  'identity-hold value (9.9) is absent from the latest-results data'
);
select is(
  (select status from public.patient_latest_results('00000000-0000-0000-0000-0000000a1001')
    where analyte_key = 'hscrp'),
  'needs_review',
  'needs-review hsCRP DOES appear in latest-results with its Needs review status'
);

select * from finish();
rollback;
