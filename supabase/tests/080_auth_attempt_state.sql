-- auth_attempt_state: zero policies + revoked table grants, same shape as
-- mfa_recovery_codes. Touched only by auth hooks / SECURITY DEFINER
-- functions (TC-005 step 2) - never directly readable or writable by a
-- client role, including the row's own subject.
begin;
select no_plan();

insert into public.auth_attempt_state (user_id, wrong_count) values ('00000000-0000-0000-0000-0000000a0002', 2);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select throws_ok(
  $$ select count(*) from public.auth_attempt_state $$,
  '42501', null,
  'org_admin_a cannot read auth_attempt_state - grants are revoked'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- the subject of the row
select throws_ok(
  $$ select count(*) from public.auth_attempt_state $$,
  '42501', null,
  'even the row''s own subject cannot read their auth_attempt_state row directly'
);
select throws_ok(
  $$ update public.auth_attempt_state set wrong_count = 0 where user_id = '00000000-0000-0000-0000-0000000a0002' $$,
  '42501', null,
  'no client role can update auth_attempt_state - grants are revoked'
);

select * from finish();
rollback;
