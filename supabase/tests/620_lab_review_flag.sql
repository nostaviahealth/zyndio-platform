-- TC-011 M2: flag_lab_report_needs_review() lets a care_coordinator (and a
-- physician) raise a "Needs review" flag in their own org, but a
-- coordinator still cannot UPDATE lab_reports directly (data stays
-- physician-only, per 20261026150000). read_only and cross-org callers are
-- denied.
begin;
select no_plan();

-- care_coordinator_a can flag an in-org report.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2'); -- care_coordinator_a
select lives_ok(
  $$ select public.flag_lab_report_needs_review('00000000-0000-0000-0000-0000000a3001') $$,
  'care_coordinator_a can flag an in-org lab report'
);
select is(
  (select needs_review from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  true,
  'needs_review is set true after the flag RPC'
);
select isnt(
  (select flagged_by from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  null,
  'flagged_by is recorded'
);

-- Flagging is the only door open to a coordinator: a direct UPDATE (even to
-- clear the same flag, or to touch data) is still denied by RLS.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2'); -- care_coordinator_a
update public.lab_reports set report_type = 'tampered' where id = '00000000-0000-0000-0000-0000000a3001';
select isnt(
  (select report_type from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  'tampered',
  'care_coordinator_a still cannot UPDATE lab_reports data directly'
);
update public.lab_reports set needs_review = false where id = '00000000-0000-0000-0000-0000000a3001';
select is(
  (select needs_review from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  true,
  'care_coordinator_a cannot clear needs_review via a direct UPDATE either (no UPDATE grant at all)'
);

-- A physician may also flag, and may clear it again via the normal
-- physician-only UPDATE policy (reviewing/confirming a value).
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select lives_ok(
  $$ select public.flag_lab_report_needs_review('00000000-0000-0000-0000-0000000a3001') $$,
  'physician_a can also flag an in-org lab report'
);
update public.lab_reports set needs_review = false where id = '00000000-0000-0000-0000-0000000a3001';
select is(
  (select needs_review from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  false,
  'physician_a can clear needs_review via the existing physician UPDATE policy'
);

-- read_only has no SELECT/UPDATE on lab_reports at all (Review group A, H2)
-- and is not a flaggable role, so the RPC must refuse it outright.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2'); -- read_only_a
select throws_ok(
  $$ select public.flag_lab_report_needs_review('00000000-0000-0000-0000-0000000a3001') $$,
  '42501', null,
  'read_only_a cannot call flag_lab_report_needs_review'
);

-- org_admin is not a clinical role either.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select throws_ok(
  $$ select public.flag_lab_report_needs_review('00000000-0000-0000-0000-0000000a3001') $$,
  '42501', null,
  'org_admin_a cannot call flag_lab_report_needs_review'
);

-- Cross-org: physician_b is a valid clinical role, but org B, so the lookup
-- against the report's own org must refuse it.
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2'); -- physician_b
select throws_ok(
  $$ select public.flag_lab_report_needs_review('00000000-0000-0000-0000-0000000a3001') $$,
  'P0002', null,
  'physician_b (cross-org) cannot flag org A''s lab report'
);

-- aal1 (no 2FA yet) is refused regardless of role.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal1'); -- physician_a, aal1
select throws_ok(
  $$ select public.flag_lab_report_needs_review('00000000-0000-0000-0000-0000000a3001') $$,
  '42501', null,
  'aal1 physician_a cannot call flag_lab_report_needs_review'
);

select * from finish();
rollback;
