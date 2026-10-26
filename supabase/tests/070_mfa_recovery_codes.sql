-- mfa_recovery_codes: zero policies, and table grants to anon/authenticated
-- are fully revoked. That means a client role gets a hard "permission
-- denied" on any direct access (not a silently-empty RLS filter) - this
-- table is reachable only through SECURITY DEFINER functions owned by the
-- table owner (consume_recovery_code() etc., added in TC-005 step 2). Even
-- an org_admin, and even the row's own owning user, get nothing directly.
begin;
select no_plan();

insert into public.mfa_recovery_codes (id, user_id, factor_id, code_hash)
  values ('00000000-0000-0000-0000-0000000a7001', '00000000-0000-0000-0000-0000000a1001', gen_random_uuid(), 'fixturehash');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select throws_ok(
  $$ select count(*) from public.mfa_recovery_codes $$,
  '42501', null,
  'org_admin_a cannot read mfa_recovery_codes - grants are revoked, not just RLS-filtered'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2'); -- the owning patient
select throws_ok(
  $$ select count(*) from public.mfa_recovery_codes $$,
  '42501', null,
  'even the owning user cannot read their own mfa_recovery_codes row directly'
);
select throws_ok(
  $$ insert into public.mfa_recovery_codes (id, user_id, factor_id, code_hash)
     values ('00000000-0000-0000-0000-0000000a7002', '00000000-0000-0000-0000-0000000a1001', gen_random_uuid(), 'x') $$,
  '42501', null,
  'no client role can insert into mfa_recovery_codes - grants are revoked'
);

select * from finish();
rollback;
