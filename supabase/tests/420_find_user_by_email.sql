-- TC-005 step 3: find_user_id_by_email() is the service-role-only
-- replacement for GoTrue's admin listUsers endpoint (which 500s once any
-- account has a NULL confirmation_token - see invite-user/index.ts and
-- scripts/supabase-admin-setup.ts for the live bug this avoids).
begin;
select no_plan();

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select throws_ok(
  $$ select public.find_user_id_by_email('org-admin-a@example.test') $$,
  '42501', null,
  'an authenticated caller (even an org_admin) cannot execute find_user_id_by_email - service_role only'
);

select tests.authenticate_as_anon();
select throws_ok(
  $$ select public.find_user_id_by_email('org-admin-a@example.test') $$,
  '42501', null,
  'anon cannot execute find_user_id_by_email'
);

reset role;
set role service_role;
select is(
  public.find_user_id_by_email('org-admin-a@example.test'),
  '00000000-0000-0000-0000-0000000a0001'::uuid,
  'service_role resolves a known email to its user id'
);
select is(
  public.find_user_id_by_email('ORG-ADMIN-A@EXAMPLE.TEST'),
  '00000000-0000-0000-0000-0000000a0001'::uuid,
  'the lookup is case-insensitive'
);
select is(
  public.find_user_id_by_email('no-such-user@example.test'),
  null,
  'an unknown email resolves to null, not an error'
);
reset role;

select * from finish();
rollback;
