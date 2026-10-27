-- TC-013 Clara L15: flagged_by / flagged_at on lab_reports must only ever be
-- set by flag_lab_report_needs_review() (which derives them from auth.uid()
-- / now()), never by a direct client UPDATE - even though
-- lab_reports_physician_update otherwise lets a physician write any column
-- on an in-org row.
begin;
select no_plan();

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select lives_ok(
  $$ select public.flag_lab_report_needs_review('00000000-0000-0000-0000-0000000a3001') $$,
  'physician_a flags the report via the RPC'
);
select is(
  (select flagged_by from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  '00000000-0000-0000-0000-0000000a0002'::uuid,
  'flagged_by is set to the RPC caller'
);

-- A direct UPDATE of flagged_by (forging who raised the flag) is silently
-- ignored - the row keeps the RPC-set value rather than erroring, same as
-- every other write this policy would otherwise allow.
update public.lab_reports
  set flagged_by = '00000000-0000-0000-0000-0000000a0003' -- care_coordinator_a's id
  where id = '00000000-0000-0000-0000-0000000a3001';
select is(
  (select flagged_by from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  '00000000-0000-0000-0000-0000000a0002'::uuid,
  'a direct UPDATE of flagged_by by a physician is ignored, not applied'
);

-- Same for flagged_at.
update public.lab_reports
  set flagged_at = '2000-01-01T00:00:00Z'
  where id = '00000000-0000-0000-0000-0000000a3001';
select isnt(
  (select flagged_at from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  '2000-01-01T00:00:00Z'::timestamptz,
  'a direct UPDATE of flagged_at by a physician is ignored, not applied'
);

-- Other columns on the same row are unaffected by the trigger - a
-- physician can still clear needs_review directly (620_lab_review_flag.sql's
-- existing, still-sanctioned path).
update public.lab_reports set needs_review = false where id = '00000000-0000-0000-0000-0000000a3001';
select is(
  (select needs_review from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  false,
  'a direct UPDATE of needs_review (not a flag column) still works'
);

-- The RPC still works end to end after all of the above direct-write
-- attempts - the trigger only ever blocks the two flag columns outside the
-- RPC's own write, never the RPC itself.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2'); -- care_coordinator_a
select lives_ok(
  $$ select public.flag_lab_report_needs_review('00000000-0000-0000-0000-0000000a3001') $$,
  'the flag RPC still works after the trigger blocked direct writes'
);
select is(
  (select flagged_by from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  '00000000-0000-0000-0000-0000000a0003'::uuid,
  'the RPC can still set flagged_by to the new caller'
);
select is(
  (select needs_review from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  true,
  'the RPC still sets needs_review = true'
);

select * from finish();
rollback;
