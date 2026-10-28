-- Clara L27: raising needs_review (false → true) is only allowed through
-- flag_lab_report_needs_review() (same owner-role gate as L25). A direct
-- UPDATE that raises the flag is rejected. Every clear (true → false) writes
-- an audit_log row with the actor, previous flagged_by / flagged_at, and
-- lab_report_id (no patient data), then nulls the columns (L26).
begin;
select no_plan();

-- Direct raise by an in-org physician is rejected (no silent false→true).
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select throws_ok(
  $$ update public.lab_reports
       set needs_review = true
     where id = '00000000-0000-0000-0000-0000000a3001' $$,
  '42501', null,
  'a direct UPDATE that raises needs_review is rejected'
);
select is(
  (select needs_review from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  false,
  'needs_review stays false after the rejected direct raise'
);

-- RPC raise succeeds and is audited.
select lives_ok(
  $$ select public.flag_lab_report_needs_review('00000000-0000-0000-0000-0000000a3001') $$,
  'flag_lab_report_needs_review still raises the flag'
);
select is(
  (select needs_review from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  true,
  'RPC sets needs_review = true'
);
select is(
  (select flagged_by from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  '00000000-0000-0000-0000-0000000a0002'::uuid,
  'RPC sets flagged_by to the caller'
);
reset role;
select set_config('request.jwt.claims', '', true);
select ok(
  exists(
    select 1 from public.audit_log
     where event_type = 'lab_report_flagged_needs_review'
       and actor_user_id = '00000000-0000-0000-0000-0000000a0002'
       and metadata->>'lab_report_id' = '00000000-0000-0000-0000-0000000a3001'
  ),
  'RPC raise writes lab_report_flagged_needs_review audit row'
);

-- Capture provenance before clear for the clear-audit assertion.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select isnt(
  (select flagged_at from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  null,
  'precondition: flagged_at is set before clear'
);

-- Physician clear (existing direct UPDATE path) audits and nulls columns.
update public.lab_reports
  set needs_review = false
  where id = '00000000-0000-0000-0000-0000000a3001';
select is(
  (select needs_review from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  false,
  'physician_a can still clear needs_review via direct UPDATE'
);
select is(
  (select flagged_by from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  null,
  'clear nulls flagged_by (L26)'
);
select is(
  (select flagged_at from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  null,
  'clear nulls flagged_at (L26)'
);
reset role;
select set_config('request.jwt.claims', '', true);
select ok(
  exists(
    select 1 from public.audit_log
     where event_type = 'lab_report_needs_review_cleared'
       and actor_user_id = '00000000-0000-0000-0000-0000000a0002'
       and metadata->>'lab_report_id' = '00000000-0000-0000-0000-0000000a3001'
       and metadata->>'previous_flagged_by' = '00000000-0000-0000-0000-0000000a0002'
       and metadata ? 'previous_flagged_at'
       and not (metadata ? 'patient_id')
  ),
  'clear writes lab_report_needs_review_cleared with actor, report id, previous flag columns, no patient_id'
);

-- Cross-org: physician_b cannot clear org A's flagged report.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select lives_ok(
  $$ select public.flag_lab_report_needs_review('00000000-0000-0000-0000-0000000a3001') $$,
  're-flag so there is something for cross-org clear to fail against'
);
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2'); -- physician_b
update public.lab_reports
  set needs_review = false
  where id = '00000000-0000-0000-0000-0000000a3001';
-- RLS hides org A rows from physician_b; read back as the pg_prove role.
reset role;
select set_config('request.jwt.claims', '', true);
select is(
  (select needs_review from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  true,
  'physician_b (cross-org) cannot clear org A''s needs_review'
);
select is(
  (select count(*)::int from public.audit_log
    where event_type = 'lab_report_needs_review_cleared'
      and actor_user_id = '00000000-0000-0000-0000-0000000b0001'
      and metadata->>'lab_report_id' = '00000000-0000-0000-0000-0000000a3001'),
  0,
  'cross-org clear attempt writes no clear audit row'
);

select * from finish();
rollback;
