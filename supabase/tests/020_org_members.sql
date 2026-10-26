-- org_members: self_select (any aal), admin_select/admin_update (org_admin
-- + aal2 only), no insert/delete policy at all (membership rows are created
-- only by the invite-acceptance flow / SECURITY DEFINER RPCs - TC-005 step 3).
begin;
select no_plan();

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select is(
  (select count(*) from public.org_members)::int,
  4,
  'org_admin_a (aal2) sees all 4 members of org A'
);
select is(
  (select count(*) from public.org_members where org_id = '00000000-0000-0000-0000-00000000000b')::int,
  0,
  'org_admin_a sees no org B members, even via admin_select'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a (not an admin)
select is(
  (select array_agg(user_id) from public.org_members),
  array['00000000-0000-0000-0000-0000000a0002']::uuid[],
  'physician_a only sees their own row (self_select), not the rest of org A'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2'); -- physician_b, cross-org
select is(
  (select array_agg(user_id) from public.org_members),
  array['00000000-0000-0000-0000-0000000b0001']::uuid[],
  'physician_b (cross-org) only sees their own row'
);

-- Review group A, finding H1 (Clara PR #4 pre-review; Henry's binding
-- ruling): a direct client UPDATE on org_members must be DENIED even for an
-- org_admin at aal2 - it bypasses change_member_role() and leaves no audit
-- row. This assertion used to read the opposite way ("org_admin_a can
-- update a same-org teammate's status") before the org_members_admin_update
-- policy existed at all; that was wrong per Henry and is corrected here, not
-- weakened - the only sanctioned paths are change_member_role() and the
-- Edge Functions (deactivate-user/reactivate-user/accept-invite).
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
select throws_ok(
  $$ update public.org_members set status = 'deactivated' where user_id = '00000000-0000-0000-0000-0000000a0004' $$,
  null, null,
  'org_admin_a (aal2) cannot update a same-org teammate''s status via a direct UPDATE'
);
select throws_ok(
  $$ update public.org_members set role = 'read_only' where user_id = '00000000-0000-0000-0000-0000000a0004' $$,
  null, null,
  'org_admin_a (aal2) cannot change a same-org teammate''s role via a direct UPDATE'
);
select throws_ok(
  $$ update public.org_members set user_id = '00000000-0000-0000-0000-0000000a9001' where user_id = '00000000-0000-0000-0000-0000000a0004' $$,
  null, null,
  'org_admin_a (aal2) cannot re-point a membership row at another auth user via a direct UPDATE'
);

-- a non-admin cannot update anyone, including themselves - UPDATE is
-- revoked from authenticated entirely now, so this is a permission error,
-- not just a policy that filters out the row.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select throws_ok(
  $$ update public.org_members set status = 'deactivated' where user_id = '00000000-0000-0000-0000-0000000a0002' $$,
  null, null,
  'physician_a (non-admin) cannot update their own org_members row'
);

-- no INSERT policy for anyone, including an org_admin.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
select throws_ok(
  $$ insert into public.org_members (user_id, org_id, role, status)
     values ('00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000000000a', 'physician', 'active') $$,
  null, null,
  'no INSERT policy exists on org_members, even for an org_admin'
);

-- the only sanctioned path: change_member_role() writes an audit row for
-- every call. audit_log itself is unreadable to any client role (090), so
-- this reads it back as the superuser the pg_prove connection started as.
reset role;
select set_config('request.jwt.claims', '', true);
select is(
  (select count(*) from public.audit_log where event_type = 'role_changed')::int,
  0,
  'sanity: no role_changed audit rows yet'
);
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select lives_ok(
  $$ select public.change_member_role('00000000-0000-0000-0000-0000000a0004', 'physician') $$,
  'org_admin_a can change a teammate''s role via change_member_role()'
);
reset role;
select set_config('request.jwt.claims', '', true);
select is(
  (select count(*) from public.audit_log
     where event_type = 'role_changed'
       and actor_user_id = '00000000-0000-0000-0000-0000000a0001'
       and target_user_id = '00000000-0000-0000-0000-0000000a0004')::int,
  1,
  'change_member_role() wrote exactly one audit row for the role change'
);

select * from finish();
rollback;
