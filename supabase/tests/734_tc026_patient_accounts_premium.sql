-- TC-026: a patient can read their own patient_accounts row (including the
-- premium fields) and cannot read another patient's row, but can never set
-- is_premium/subscription_plan/subscription_expires_at themselves - via
-- direct UPDATE, INSERT, or UPSERT (ON CONFLICT DO UPDATE). Only the
-- service-role RevenueCat webhook writes those columns.
begin;
select no_plan();

insert into public.patient_accounts (patient_id, name, is_premium, subscription_plan)
  values
    ('00000000-0000-0000-0000-0000000a1001', 'Fictional Patient A1', false, 'free'),
    ('00000000-0000-0000-0000-0000000b1001', 'Fictional Patient B1', false, 'free');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2'); -- patient_a1

select is(
  (select is_premium from public.patient_accounts where patient_id = '00000000-0000-0000-0000-0000000a1001'),
  false,
  'patient_a1 can read their own is_premium (false)'
);

select is(
  (select name from public.patient_accounts where patient_id = '00000000-0000-0000-0000-0000000b1001'),
  null,
  'patient_a1 cannot read patient_b1''s row at all'
);

-- Direct UPDATE of the premium column alone.
select throws_ok(
  $$ update public.patient_accounts set is_premium = true where patient_id = '00000000-0000-0000-0000-0000000a1001' $$,
  '42501', null,
  'patient_a1 cannot UPDATE their own is_premium column'
);

select throws_ok(
  $$ update public.patient_accounts set subscription_plan = 'plus' where patient_id = '00000000-0000-0000-0000-0000000a1001' $$,
  '42501', null,
  'patient_a1 cannot UPDATE their own subscription_plan column'
);

-- An UPDATE touching both an allowed column and a protected one must still
-- fail entirely (no partial write) rather than silently dropping the
-- protected column.
select throws_ok(
  $$ update public.patient_accounts set name = 'Sneaky Rename', is_premium = true where patient_id = '00000000-0000-0000-0000-0000000a1001' $$,
  '42501', null,
  'patient_a1 cannot smuggle an is_premium write alongside an allowed column update'
);

-- Upsert (ON CONFLICT DO UPDATE) is how the Flutter client normally writes
-- this row - it must be blocked exactly the same way as a plain UPDATE.
select throws_ok(
  $$ insert into public.patient_accounts (patient_id, is_premium)
     values ('00000000-0000-0000-0000-0000000a1001', true)
     on conflict (patient_id) do update set is_premium = excluded.is_premium $$,
  '42501', null,
  'patient_a1 cannot upsert their own is_premium via ON CONFLICT DO UPDATE'
);

-- Confirm none of the above attempts actually changed anything.
select is(
  (select is_premium from public.patient_accounts where patient_id = '00000000-0000-0000-0000-0000000a1001'),
  false,
  'is_premium is still false after every blocked write attempt'
);

-- A column-only INSERT of a brand new row with is_premium set is also
-- refused (insert goes through the same column-privilege check).
select throws_ok(
  $$ insert into public.patient_accounts (patient_id, is_premium)
     values ('00000000-0000-0000-0000-0000000a6099', true) $$,
  '42501', null,
  'patient_a1 cannot INSERT a new row with is_premium set'
);

-- The patient can still update an allowed column on their own row.
update public.patient_accounts set name = 'Updated Name A1' where patient_id = '00000000-0000-0000-0000-0000000a1001';
select is(
  (select name from public.patient_accounts where patient_id = '00000000-0000-0000-0000-0000000a1001'),
  'Updated Name A1',
  'patient_a1 can still update an unprotected column (name) on their own row'
);

-- service_role (the RevenueCat webhook's identity) is unaffected by the
-- column revoke - it only applies to authenticated/anon.
select tests.authenticate_as_service_role();
update public.patient_accounts set is_premium = true, subscription_plan = 'plus'
  where patient_id = '00000000-0000-0000-0000-0000000a1001';
select is(
  (select is_premium from public.patient_accounts where patient_id = '00000000-0000-0000-0000-0000000a1001'),
  true,
  'service_role (webhook identity) can set is_premium'
);

select * from finish();
rollback;
