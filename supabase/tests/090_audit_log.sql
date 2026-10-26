-- audit_log: append-only, zero client policies, and table grants to
-- anon/authenticated are fully revoked. The only sanctioned write path is
-- write_audit_log() (SECURITY DEFINER, owned by the table owner) - no
-- client role, not even org_admin, can read or write the table directly,
-- and there are no UPDATE/DELETE grants to anyone ever.
begin;
select no_plan();

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select throws_ok(
  $$ select count(*) from public.audit_log $$,
  null, null,
  'org_admin_a cannot read audit_log directly - grants are revoked'
);
select throws_ok(
  $$ insert into public.audit_log (actor_user_id, target_user_id, org_id, event_type)
     values ('00000000-0000-0000-0000-0000000a0001', '00000000-0000-0000-0000-0000000a0002', '00000000-0000-0000-0000-00000000000a', 'role_changed') $$,
  null, null,
  'no client role can insert into audit_log directly - the only path is write_audit_log()'
);

-- write_audit_log() is SECURITY DEFINER and owned by the table owner, so it
-- can write on an authenticated caller's behalf even though that caller has
-- no direct grant on the table.
select lives_ok(
  $$ select public.write_audit_log('role_changed', '00000000-0000-0000-0000-0000000a0001', '00000000-0000-0000-0000-0000000a0002', '00000000-0000-0000-0000-00000000000a', '{}'::jsonb) $$,
  'org_admin_a can write an audit row via write_audit_log()'
);
-- still not directly selectable afterwards - the function's privilege does
-- not leak into the caller's own grants.
select throws_ok(
  $$ select count(*) from public.audit_log $$,
  null, null,
  'the audit row written via write_audit_log() is still not directly selectable by the caller'
);

select * from finish();
rollback;
