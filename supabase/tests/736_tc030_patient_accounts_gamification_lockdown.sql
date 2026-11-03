-- TC-030 item 1 (Clara PR #25 M1): a patient can no longer write their own
-- gamification state (xp, coins, league_xp, current_league, league_badges) -
-- via direct UPDATE, a multi-column UPDATE, or an upsert - so the clinic
-- leaderboard cannot be rigged. The server-side award path
-- (award_patient_points, service_role only) can still set them.
--
-- Fail-first: on the pre-20261102162000 schema these five columns still carried
-- the authenticated column grant from 20261102090000, so every throws_ok below
-- would instead return 200/succeed (the exploit Clara confirmed), and
-- award_patient_points does not exist (the service_role assertion errors on a
-- missing function). After the migration, the patient writes raise 42501 and the
-- award RPC exists and works.
begin;
select no_plan();

insert into public.patient_accounts (patient_id, name, xp, coins, league_xp, current_league)
  values ('00000000-0000-0000-0000-0000000a1001', 'Fictional Patient A1', 10, 5, 10, 'bronze');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2'); -- patient_a1

-- Each gamification column is individually denied at the column-privilege level.
select throws_ok(
  $$ update public.patient_accounts set xp = 999999 where patient_id = '00000000-0000-0000-0000-0000000a1001' $$,
  '42501', null,
  'patient_a1 cannot UPDATE their own xp column'
);
select throws_ok(
  $$ update public.patient_accounts set coins = 999999 where patient_id = '00000000-0000-0000-0000-0000000a1001' $$,
  '42501', null,
  'patient_a1 cannot UPDATE their own coins column'
);
select throws_ok(
  $$ update public.patient_accounts set league_xp = 999999 where patient_id = '00000000-0000-0000-0000-0000000a1001' $$,
  '42501', null,
  'patient_a1 cannot UPDATE their own league_xp column (the leaderboard-rigging vector)'
);
select throws_ok(
  $$ update public.patient_accounts set current_league = 'legendary' where patient_id = '00000000-0000-0000-0000-0000000a1001' $$,
  '42501', null,
  'patient_a1 cannot UPDATE their own current_league column'
);
select throws_ok(
  $$ update public.patient_accounts set league_badges = '{"legend":true}'::jsonb where patient_id = '00000000-0000-0000-0000-0000000a1001' $$,
  '42501', null,
  'patient_a1 cannot UPDATE their own league_badges column'
);

-- A multi-column UPDATE that smuggles league_xp alongside an allowed column
-- (name) must still fail entirely - no partial write.
select throws_ok(
  $$ update public.patient_accounts set name = 'Sneaky', league_xp = 999999 where patient_id = '00000000-0000-0000-0000-0000000a1001' $$,
  '42501', null,
  'patient_a1 cannot smuggle a league_xp write alongside an allowed column update'
);

-- Upsert (ON CONFLICT DO UPDATE) is the Flutter client's normal write shape and
-- must be blocked the same way when it names a gamification column.
select throws_ok(
  $$ insert into public.patient_accounts (patient_id, league_xp)
     values ('00000000-0000-0000-0000-0000000a1001', 999999)
     on conflict (patient_id) do update set league_xp = excluded.league_xp $$,
  '42501', null,
  'patient_a1 cannot upsert their own league_xp via ON CONFLICT DO UPDATE'
);

-- A brand-new row that names a gamification column in the INSERT list is refused
-- too (insert goes through the same column-privilege check). a6002 has no row.
select throws_ok(
  $$ insert into public.patient_accounts (patient_id, league_xp)
     values ('00000000-0000-0000-0000-0000000a6002', 999999) $$,
  '42501', null,
  'patient_a1 cannot INSERT a row that sets league_xp'
);

-- None of the blocked attempts changed anything.
select is(
  (select league_xp from public.patient_accounts where patient_id = '00000000-0000-0000-0000-0000000a1001'),
  10,
  'league_xp is unchanged after every blocked write attempt'
);

-- The patient can still create their OWN row when it omits the gamification
-- columns (they fall back to defaults with no privilege check). Authenticate as
-- a6002 so the row is its own (RLS with check (patient_id = auth.uid())).
select tests.authenticate_as('00000000-0000-0000-0000-0000000a6002', 'aal2'); -- patient_a2
insert into public.patient_accounts (patient_id, name)
  values ('00000000-0000-0000-0000-0000000a6002', 'Fictional Patient A2');
select is(
  (select league_xp from public.patient_accounts where patient_id = '00000000-0000-0000-0000-0000000a6002'),
  0,
  'a patient can still create their own row (gamification columns default to 0)'
);

-- Back to patient_a1: they can still update an allowed column on their own row.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2'); -- patient_a1
update public.patient_accounts set name = 'Renamed A1' where patient_id = '00000000-0000-0000-0000-0000000a1001';
select is(
  (select name from public.patient_accounts where patient_id = '00000000-0000-0000-0000-0000000a1001'),
  'Renamed A1',
  'patient_a1 can still update an allowed column (name) on their own row'
);

-- An authenticated patient cannot call the server award path either (the body
-- refuses any non-service_role caller).
select throws_ok(
  $$ select public.award_patient_points('00000000-0000-0000-0000-0000000a1001', 500, 50, 500) $$,
  '42501', null,
  'an authenticated patient cannot call award_patient_points (service_role only)'
);
select is(
  (select league_xp from public.patient_accounts where patient_id = '00000000-0000-0000-0000-0000000a1001'),
  10,
  'the refused award_patient_points call changed nothing'
);

-- The server-side award path works for service_role: points are ADDED, league
-- is set, badges merge.
select tests.authenticate_as_service_role();
select public.award_patient_points(
  '00000000-0000-0000-0000-0000000a1001', 500, 50, 500, 'gold', '{"streak":true}'::jsonb
);
select is(
  (select league_xp from public.patient_accounts where patient_id = '00000000-0000-0000-0000-0000000a1001'),
  510,
  'award_patient_points (service_role) adds league_xp (10 + 500)'
);
select is(
  (select xp from public.patient_accounts where patient_id = '00000000-0000-0000-0000-0000000a1001'),
  510,
  'award_patient_points (service_role) adds xp (10 + 500)'
);
select is(
  (select current_league from public.patient_accounts where patient_id = '00000000-0000-0000-0000-0000000a1001'),
  'gold',
  'award_patient_points (service_role) sets current_league'
);
select is(
  (select league_badges from public.patient_accounts where patient_id = '00000000-0000-0000-0000-0000000a1001'),
  '{"streak":true}'::jsonb,
  'award_patient_points (service_role) merges league_badges'
);

select * from finish();
rollback;
