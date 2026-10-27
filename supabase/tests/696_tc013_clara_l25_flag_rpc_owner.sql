-- Clara L25: app.lab_report_flag_rpc is a custom GUC any role can set via
-- set_config, so a physician who sets it to 'on' could UPDATE flagged_by /
-- flagged_at directly and forge who raised a "Needs review" flag — bypassing
-- L15's trigger. The trigger must also require that current_user is the
-- flag_lab_report_needs_review() owner role (true only inside that
-- SECURITY DEFINER body), not merely that the GUC is on.
begin;
select no_plan();

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select lives_ok(
  $$ select public.flag_lab_report_needs_review('00000000-0000-0000-0000-0000000a3001') $$,
  'physician_a flags the report via the RPC (baseline)'
);
select is(
  (select flagged_by from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  '00000000-0000-0000-0000-0000000a0002'::uuid,
  'flagged_by is the RPC caller'
);

-- Forge attempt: set the same GUC the RPC uses, then write flagged_by.
select set_config('app.lab_report_flag_rpc', 'on', true);
update public.lab_reports
  set flagged_by = '00000000-0000-0000-0000-0000000a0003' -- care_coordinator_a
  where id = '00000000-0000-0000-0000-0000000a3001';
select is(
  (select flagged_by from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  '00000000-0000-0000-0000-0000000a0002'::uuid,
  'forging flagged_by with the GUC set (but current_user != function owner) is ignored'
);

select set_config('app.lab_report_flag_rpc', 'on', true);
update public.lab_reports
  set flagged_at = '2000-01-01T00:00:00Z'
  where id = '00000000-0000-0000-0000-0000000a3001';
select isnt(
  (select flagged_at from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  '2000-01-01T00:00:00Z'::timestamptz,
  'forging flagged_at with the GUC set (but current_user != function owner) is ignored'
);

-- The RPC itself still works: inside SECURITY DEFINER, current_user is the
-- function owner, so the GUC + owner check both pass.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2'); -- care_coordinator_a
select lives_ok(
  $$ select public.flag_lab_report_needs_review('00000000-0000-0000-0000-0000000a3001') $$,
  'the flag RPC still sets flagged_by after the forge attempts'
);
select is(
  (select flagged_by from public.lab_reports where id = '00000000-0000-0000-0000-0000000a3001'),
  '00000000-0000-0000-0000-0000000a0003'::uuid,
  'RPC sets flagged_by to the new caller'
);

select * from finish();
rollback;
