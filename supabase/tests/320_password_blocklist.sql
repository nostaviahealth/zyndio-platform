-- password_is_blocked(): case-insensitive check against the server-side
-- blocklist (OVERRIDES #13), callable by authenticated/service_role; the
-- underlying table stays unreachable directly (same zero-policy pattern as
-- the other SECURITY DEFINER-only tables).
--
-- B2 / L6 (review group B): anon's EXECUTE grant is revoked. Every caller
-- that needs this pre-authentication (accept-invite) already uses the
-- service-role client, not the anon key, so anon never legitimately needed
-- it - it was a harmless-but-needless oracle on public data. This test used
-- to assert anon *could* call it; that assertion is corrected here (not
-- weakened) to match the revoke.
begin;
select no_plan();

-- TC-011 M3: the stopgap generated list (TC-005 review group B) is replaced
-- by the real SecLists 10k-most-common.txt corpus (MIT licence; see
-- supabase/seed_data/README.md and 20261027120000_tc011_real_password_blocklist.sql).
-- 'password' and 'trustno1' are real entries from that list, not generated
-- base-word+suffix combos.
select ok(
  public.password_is_blocked('password'),
  'a blocklisted password (exact case) is blocked'
);
select ok(
  public.password_is_blocked('PASSWORD'),
  'the check is case-insensitive - all-uppercase variant is blocked'
);
select ok(
  public.password_is_blocked('Password'),
  'the check is case-insensitive - mixed-case variant is blocked'
);
select ok(
  public.password_is_blocked('trustno1'),
  'a second blocklisted password (SecLists entry) is blocked'
);
select ok(
  not public.password_is_blocked('a-fictional-unguessable-pass-7Q2'),
  'a password not on the list is not blocked'
);

select tests.authenticate_as_anon();
select throws_ok(
  $$ select public.password_is_blocked('password') $$,
  '42501', null,
  'anon cannot call password_is_blocked() (L6) - every legitimate caller uses the service-role client'
);
select throws_ok(
  $$ select count(*) from public.password_blocklist $$,
  '42501', null,
  'anon cannot read the password_blocklist table directly - only via the function'
);

reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select ok(
  public.password_is_blocked('password'),
  'authenticated can still call password_is_blocked() (needed by change-password)'
);
select throws_ok(
  $$ select count(*) from public.password_blocklist $$,
  '42501', null,
  'authenticated cannot read the password_blocklist table directly either'
);
reset role;
select cmp_ok(
  (select count(*)::int from public.password_blocklist), '>', 9000,
  'the blocklist carries the full ~10k SecLists corpus, not just a few hundred literals'
);

select * from finish();
rollback;
