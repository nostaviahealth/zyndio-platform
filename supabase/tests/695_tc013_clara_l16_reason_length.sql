-- TC-013 Clara L16: request_mfa_reset's p_reason is capped at 500 chars
-- server-side, independent of whatever the UI enforces.
begin;
select no_plan();

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a

select lives_ok(
  $$ select public.request_mfa_reset('00000000-0000-0000-0000-0000000a0002', repeat('x', 500)) $$,
  'exactly 500 chars is accepted'
);

select throws_ok(
  $$ select public.request_mfa_reset('00000000-0000-0000-0000-0000000a0002', repeat('x', 501)) $$,
  '22001', 'reason must be 500 characters or fewer',
  '501 chars is rejected'
);

select lives_ok(
  $$ select public.request_mfa_reset('00000000-0000-0000-0000-0000000a0002', null) $$,
  'a null reason is still accepted'
);

select * from finish();
rollback;
