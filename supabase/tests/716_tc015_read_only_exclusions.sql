-- TC-015 fix round (Leo ruling, 28 Oct): read_only's identity-hold exclusion
-- must not depend on read_only being able to SELECT lab_reports directly (H2
-- stands for lab_reports - see 050_lab_reports.sql, 210_in_org_role_matrix.sql,
-- 500_review_probes.sql, restored to deny read_only any lab_reports row).
-- patient_trend and patient_latest_results must still exclude identity-hold
-- results for read_only, exactly as for physician/care_coordinator, and must
-- fail CLOSED (never show a held value) rather than relying on a join/
-- NOT EXISTS against a table read_only cannot see.
--
-- Fixtures live in this file's own transaction, TC-015-namespaced (716...),
-- rolled back at the end.
begin;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);

insert into public.lab_reports (id, org_id, patient_id, report_type, data, identity_hold) values
  ('00000000-0000-0000-0000-00000016a301', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'metabolic_panel', '{}', false),
  ('00000000-0000-0000-0000-00000016a302', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'metabolic_panel', '{}', true);

insert into public.lab_results
  (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value, original_value, unit, status, is_unmapped, range_low, range_high, taken_at) values
  -- valid HbA1c point on the visible report
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000016a301', 'hba1c', 'HbA1c', 5.5, null, '%', 'within_range', false, null, 5.7, now() - interval '20 days'),
  -- identity-hold HbA1c point (most recent) - must never appear in trend or latest
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000016a302', 'hba1c', 'HbA1c', 9.9, null, '%', 'within_range', false, null, 5.7, now() - interval '5 days'),
  -- needs-review hsCRP: never in trend
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000016a301', 'hscrp', 'hsCRP', 1.7, null, 'mg/L', 'needs_review', false, null, null, now() - interval '10 days'),
  -- unmapped Lp-PLA2: never in trend
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000016a301', 'lp_pla2', 'Lp-PLA2', 171, null, 'nmol/min/mL', 'no_range', true, null, null, now() - interval '10 days');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2'); -- read_only_a

-- ----- read_only_a cannot read lab_reports directly (H2 stands) -----
select is(
  (select count(*) from public.lab_reports where id in (
    '00000000-0000-0000-0000-00000016a301', '00000000-0000-0000-0000-00000016a302'))::int,
  0,
  'read_only_a sees no lab_reports rows directly (H2 stands)'
);

-- ----- identity-hold result excluded from read_only_a''s trend -----
select is(
  (select count(*) from public.patient_trend('00000000-0000-0000-0000-0000000a1001', 'hba1c', 'ALL'))::int,
  1,
  'read_only_a HbA1c trend has only the visible point (identity-hold 9.9 excluded)'
);
select is(
  (select count(*) from public.patient_trend('00000000-0000-0000-0000-0000000a1001', 'hba1c', 'ALL')
    where value = 9.9)::int,
  0,
  'read_only_a: identity-hold HbA1c value (9.9) is absent from the trend'
);

-- ----- needs-review / unmapped excluded from read_only_a''s trend -----
select is(
  (select count(*) from public.patient_trend('00000000-0000-0000-0000-0000000a1001', 'hscrp', 'ALL'))::int,
  0,
  'read_only_a: needs-review hsCRP is absent from the trend'
);
select is(
  (select count(*) from public.patient_trend('00000000-0000-0000-0000-0000000a1001', 'lp_pla2', 'ALL'))::int,
  0,
  'read_only_a: unmapped Lp-PLA2 is absent from the trend'
);

-- ----- latest-results: own-clinic latest shown, identity-hold never shown -----
select is(
  (select value from public.patient_latest_results('00000000-0000-0000-0000-0000000a1001')
    where analyte_key = 'hba1c'),
  5.5::numeric,
  'read_only_a: latest HbA1c is the visible 5.5 (identity-hold 9.9 excluded from latest)'
);
select is(
  (select count(*) from public.patient_latest_results('00000000-0000-0000-0000-0000000a1001')
    where value = 9.9)::int,
  0,
  'read_only_a: identity-hold value (9.9) is absent from the latest-results data'
);

select * from finish();
rollback;
