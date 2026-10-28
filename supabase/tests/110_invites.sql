-- invites: org_admin can SELECT pending/accepted invites for their own org
-- (aal2 required); no INSERT/UPDATE/DELETE policy - creating/revoking an
-- invite is an Edge Function using the service role (TC-005 step 3), not a
-- client-writable policy here.
begin;
select no_plan();

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select is(
  (select array_agg(id) from public.invites),
  array['00000000-0000-0000-0000-0000000a5001']::uuid[],
  'org_admin_a sees the pending invite for their own org'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a, not an admin
select is(
  (select count(*) from public.invites)::int,
  0,
  'physician_a (non-admin) cannot see invites even in their own org'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2'); -- physician_b, cross-org (also not an admin)
select is(
  (select count(*) from public.invites)::int,
  0,
  'physician_b (cross-org, non-admin) cannot see org A invites'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
select throws_ok(
  $$ insert into public.invites (id, org_id, email, role, token_hash)
     values ('00000000-0000-0000-0000-0000000a5002', '00000000-0000-0000-0000-00000000000a', 'another-invitee@example.test', 'physician', 'x') $$,
  '42501', null,
  'no INSERT policy exists on invites, even for an org_admin - that path is an Edge Function'
);

select * from finish();
rollback;
