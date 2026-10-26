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

-- admin_update: org_admin_a can update a teammate's row in their own org.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
update public.org_members set status = 'deactivated' where user_id = '00000000-0000-0000-0000-0000000a0004';
select is(
  (select status from public.org_members where user_id = '00000000-0000-0000-0000-0000000a0004'),
  'deactivated',
  'org_admin_a (aal2) can update a same-org teammate''s status'
);
update public.org_members set status = 'active' where user_id = '00000000-0000-0000-0000-0000000a0004'; -- restore

-- a non-admin cannot update anyone, including themselves (no update policy for self).
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
update public.org_members set status = 'deactivated' where user_id = '00000000-0000-0000-0000-0000000a0002';
select is(
  (select status from public.org_members where user_id = '00000000-0000-0000-0000-0000000a0002'),
  'active',
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

select * from finish();
rollback;
