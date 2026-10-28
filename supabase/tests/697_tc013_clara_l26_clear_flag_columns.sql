-- Clara L26: when a physician clears needs_review via the existing UPDATE
-- policy, flagged_by / flagged_at must clear too. The audit log already
-- records who raised the flag (lab_report_flagged_needs_review), so leaving
-- the provenance columns set after the flag is gone is redundant and
-- misleading (Henry: clear both columns along with the flag).
begin;
select no_plan();

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2'); -- care_coordinator_a
select lives_ok(
  $$ select public.flag_lab_report_needs_review('00000000-0000-0000-0000-0000000a3001') $$,
  'care_coordinator_a flags the report'
);
select is(
  (select needs_review from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  true,
  'needs_review is true after flag'
);
select isnt(
  (select flagged_by from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  null,
  'flagged_by is set while the flag is up'
);
select isnt(
  (select flagged_at from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  null,
  'flagged_at is set while the flag is up'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
update public.lab_reports
  set needs_review = false
  where id = '00000000-0000-0000-0000-0000000a3001';
select is(
  (select needs_review from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  false,
  'physician_a cleared needs_review'
);
select is(
  (select flagged_by from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  null,
  'flagged_by is cleared along with the flag'
);
select is(
  (select flagged_at from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  null,
  'flagged_at is cleared along with the flag'
);

-- Audit history of the flag is retained (unreadable to client roles — 090).
reset role;
select set_config('request.jwt.claims', '', true);
select ok(
  exists(
    select 1 from public.audit_log
     where event_type = 'lab_report_flagged_needs_review'
       and actor_user_id = '00000000-0000-0000-0000-0000000a0003'
       and metadata->>'lab_report_id' = '00000000-0000-0000-0000-0000000a3001'
  ),
  'audit_log still has the flag event after the columns are cleared'
);

-- Re-flag still works and re-stamps provenance.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select lives_ok(
  $$ select public.flag_lab_report_needs_review('00000000-0000-0000-0000-0000000a3001') $$,
  're-flag after clear still works'
);
select is(
  (select flagged_by from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  '00000000-0000-0000-0000-0000000a0002'::uuid,
  're-flag sets flagged_by to the new caller'
);

select * from finish();
rollback;
