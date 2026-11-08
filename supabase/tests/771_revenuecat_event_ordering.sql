-- apply_revenuecat_event (migration 20261108130000): duplicates are no-ops,
-- an older event never overwrites a newer one, the function and the event log
-- are service-role only, and patients still cannot write premium state.
begin;
set local search_path = public, extensions, pg_catalog;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);

-- Patient a1001 exists in auth.users (global fixtures); start with no account row.
delete from public.patient_accounts where patient_id = '00000000-0000-0000-0000-0000000a1001';

select tests.authenticate_as_service_role();

-- 1. A purchase creates the row as premium, with the expiry.
select is(
  public.apply_revenuecat_event('evt-1', '00000000-0000-0000-0000-0000000a1001', 'INITIAL_PURCHASE',
    '2026-11-01 10:00+00', 'grant', '2026-12-01 10:00+00'),
  'applied', 'first purchase is applied');
select is(
  (select row(is_premium, subscription_plan, subscription_expires_at)::text from public.patient_accounts
    where patient_id = '00000000-0000-0000-0000-0000000a1001'),
  row(true, 'plus', '2026-12-01 10:00+00'::timestamptz)::text,
  'purchase sets premium, plan and expiry');

-- 2. Replaying the same event id changes nothing.
select is(
  public.apply_revenuecat_event('evt-1', '00000000-0000-0000-0000-0000000a1001', 'INITIAL_PURCHASE',
    '2026-11-01 10:00+00', 'revoke', null),
  'duplicate', 'a repeated event id is a duplicate');
select is(
  (select is_premium from public.patient_accounts where patient_id = '00000000-0000-0000-0000-0000000a1001'),
  true, 'duplicate delivery did not change premium state');

-- 3. A renewal (newer) is applied.
select is(
  public.apply_revenuecat_event('evt-3', '00000000-0000-0000-0000-0000000a1001', 'RENEWAL',
    '2026-12-01 10:00+00', 'grant', '2027-01-01 10:00+00'),
  'applied', 'newer renewal is applied');

-- 4. A delayed, OLDER expiration arrives after the renewal: recorded, not applied.
select is(
  public.apply_revenuecat_event('evt-2', '00000000-0000-0000-0000-0000000a1001', 'EXPIRATION',
    '2026-11-30 10:00+00', 'revoke', '2026-11-30 10:00+00'),
  'stale', 'an older out-of-order expiration is stale');
select is(
  (select row(is_premium, subscription_expires_at)::text from public.patient_accounts
    where patient_id = '00000000-0000-0000-0000-0000000a1001'),
  row(true, '2027-01-01 10:00+00'::timestamptz)::text,
  'stale expiration did not downgrade the renewed patient');
select is(
  (select outcome from public.revenuecat_events where event_id = 'evt-2'),
  'stale', 'stale event is still logged');

-- 5. A newer expiration is applied.
select is(
  public.apply_revenuecat_event('evt-4', '00000000-0000-0000-0000-0000000a1001', 'EXPIRATION',
    '2027-01-01 10:00+00', 'revoke', '2027-01-01 10:00+00'),
  'applied', 'newer expiration is applied');
select is(
  (select row(is_premium, subscription_plan)::text from public.patient_accounts
    where patient_id = '00000000-0000-0000-0000-0000000a1001'),
  row(false, 'free')::text,
  'newer expiration downgrades to free');

select throws_ok(
  $$ select public.apply_revenuecat_event('evt-x', '00000000-0000-0000-0000-0000000a1001', 'RENEWAL',
       now(), 'make_admin', null) $$,
  '22023', null, 'unknown action is rejected');

-- ── privileges ──
reset role;
select ok(not has_function_privilege('authenticated',
  'public.apply_revenuecat_event(text, uuid, text, timestamptz, text, timestamptz)', 'EXECUTE'),
  'authenticated cannot execute apply_revenuecat_event');
select ok(not has_function_privilege('anon',
  'public.apply_revenuecat_event(text, uuid, text, timestamptz, text, timestamptz)', 'EXECUTE'),
  'anon cannot execute apply_revenuecat_event');
select ok(has_function_privilege('service_role',
  'public.apply_revenuecat_event(text, uuid, text, timestamptz, text, timestamptz)', 'EXECUTE'),
  'service_role can execute apply_revenuecat_event');
select ok(not has_table_privilege('authenticated', 'public.revenuecat_events', 'SELECT'),
  'authenticated cannot read revenuecat_events');
select ok(not has_column_privilege('authenticated', 'public.patient_accounts', 'subscription_event_at', 'UPDATE'),
  'authenticated cannot update subscription_event_at');
select ok(not has_column_privilege('authenticated', 'public.patient_accounts', 'subscription_event_at', 'INSERT'),
  'authenticated cannot insert subscription_event_at');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select throws_ok(
  $$ select public.apply_revenuecat_event('evt-self', '00000000-0000-0000-0000-0000000a1001', 'RENEWAL',
       now(), 'grant', null) $$,
  '42501', null, 'a patient cannot grant themselves premium through the function');

select * from finish();
rollback;
