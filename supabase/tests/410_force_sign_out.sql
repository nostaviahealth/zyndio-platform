-- TC-005 step 3: force_sign_out() is deactivate-user/reset-mfa's server-side
-- stand-in for admin.signOut() on someone else's behalf (supabase-js's
-- version only works with the session's own JWT). Deletes the target's
-- auth.sessions + dependent auth.refresh_tokens rows; service_role only.
begin;
select no_plan();

-- care_coordinator_a ('...a0003') gets a fake session + refresh token.
insert into auth.sessions (id, user_id, created_at, updated_at)
values ('00000000-0000-0000-0000-0000000d0001', '00000000-0000-0000-0000-0000000a0003', now(), now());

insert into auth.refresh_tokens (instance_id, token, user_id, revoked, created_at, updated_at, session_id)
values (
  '00000000-0000-0000-0000-000000000000', 'fixture-refresh-token',
  '00000000-0000-0000-0000-0000000a0003', false, now(), now(),
  '00000000-0000-0000-0000-0000000d0001'
);

select function_returns('public', 'force_sign_out', array['uuid'], 'void', 'force_sign_out(uuid) returns void');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select throws_ok(
  $$ select public.force_sign_out('00000000-0000-0000-0000-0000000a0003'::uuid) $$,
  '42501', null,
  'an authenticated caller (even an org_admin) cannot execute force_sign_out directly - service_role only'
);

select tests.authenticate_as_anon();
select throws_ok(
  $$ select public.force_sign_out('00000000-0000-0000-0000-0000000a0003'::uuid) $$,
  '42501', null,
  'anon cannot execute force_sign_out'
);

reset role;
set role service_role;
select lives_ok(
  $$ select public.force_sign_out('00000000-0000-0000-0000-0000000a0003'::uuid) $$,
  'service_role can execute force_sign_out'
);
reset role;

select is(
  (select count(*)::int from auth.sessions where user_id = '00000000-0000-0000-0000-0000000a0003'),
  0,
  'force_sign_out deletes the target''s auth.sessions rows'
);
select is(
  (select count(*)::int from auth.refresh_tokens where user_id = '00000000-0000-0000-0000-0000000a0003'),
  0,
  'force_sign_out deletes the target''s dependent auth.refresh_tokens rows'
);

-- a user with no session at all is a no-op, not an error.
set role service_role;
select lives_ok(
  $$ select public.force_sign_out('00000000-0000-0000-0000-0000000a0004'::uuid) $$,
  'force_sign_out on a user with no session is a harmless no-op'
);
reset role;

select * from finish();
rollback;
