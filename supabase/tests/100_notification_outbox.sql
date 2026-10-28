-- notification_outbox: zero client policies, and table grants to
-- anon/authenticated are fully revoked, same shape as
-- audit_log/auth_attempt_state/mfa_recovery_codes. Populated only by
-- SECURITY DEFINER / Edge Function code paths added in later TC-005 steps;
-- no real sending happens in this card.
begin;
select no_plan();

insert into public.notification_outbox (user_id, org_id, type) values
  ('00000000-0000-0000-0000-0000000a0002', '00000000-0000-0000-0000-00000000000a', 'mfa_reset');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select throws_ok(
  $$ select count(*) from public.notification_outbox $$,
  '42501', null,
  'org_admin_a cannot read notification_outbox - grants are revoked'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- the row's own subject
select throws_ok(
  $$ select count(*) from public.notification_outbox $$,
  '42501', null,
  'even the row''s own subject cannot read their notification_outbox row directly'
);
select throws_ok(
  $$ insert into public.notification_outbox (user_id, org_id, type)
     values ('00000000-0000-0000-0000-0000000a0002', '00000000-0000-0000-0000-00000000000a', 'mfa_reset') $$,
  '42501', null,
  'no client role can insert into notification_outbox - grants are revoked'
);

select * from finish();
rollback;
