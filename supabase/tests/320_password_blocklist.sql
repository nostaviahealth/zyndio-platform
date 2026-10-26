-- password_is_blocked(): case-insensitive check against the server-side
-- blocklist (OVERRIDES #13), callable by anon/authenticated/service_role;
-- the underlying table stays unreachable directly (same zero-policy pattern
-- as the other SECURITY DEFINER-only tables).
begin;
select no_plan();

select ok(
  public.password_is_blocked('password1234'),
  'a blocklisted password (exact case) is blocked'
);
select ok(
  public.password_is_blocked('PASSWORD1234'),
  'the check is case-insensitive - all-uppercase variant is blocked'
);
select ok(
  public.password_is_blocked('Password1234'),
  'the check is case-insensitive - mixed-case variant is blocked'
);
select ok(
  public.password_is_blocked('qwertyuiop12'),
  'a second blocklisted password is blocked'
);
select ok(
  not public.password_is_blocked('a-fictional-unguessable-pass-7Q2'),
  'a password not on the list is not blocked'
);

select tests.authenticate_as_anon();
select ok(
  public.password_is_blocked('password1234'),
  'anon can call password_is_blocked() (needed pre-authentication, during invite acceptance)'
);
select throws_ok(
  $$ select count(*) from public.password_blocklist $$,
  null, null,
  'anon cannot read the password_blocklist table directly - only via the function'
);

reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select throws_ok(
  $$ select count(*) from public.password_blocklist $$,
  null, null,
  'authenticated cannot read the password_blocklist table directly either'
);

select * from finish();
rollback;
