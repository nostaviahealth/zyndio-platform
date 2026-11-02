-- TC-026 review fix (Clara H1 on PR #25 + Henry's 2 Nov scope ruling):
-- patient_leaderboard_top10() is signed-in only (anon and PUBLIC have no
-- EXECUTE, and an anon call is refused), returns only patients actively linked
-- to the caller's own clinic, and shows first name + last initial only.
-- Henry follow-up (2 Nov): the result has no patient_id column any more; it
-- carries is_me (true only for the caller's own row). Rows are identified
-- below by their (unique, fictional) display names instead of patient_id.
-- Fictional data only.
begin;
select no_plan();

-- --- Grants --------------------------------------------------------------
select ok(
  not has_function_privilege('anon', 'public.patient_leaderboard_top10()', 'execute'),
  'anon cannot execute patient_leaderboard_top10()'
);
select ok(
  not exists (
    select 1
    from pg_proc p, lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
    where p.oid = 'public.patient_leaderboard_top10()'::regprocedure
      and a.grantee = 0 and a.privilege_type = 'EXECUTE'
  ),
  'PUBLIC has no EXECUTE on patient_leaderboard_top10()'
);
select ok(
  has_function_privilege('authenticated', 'public.patient_leaderboard_top10()', 'execute'),
  'authenticated keeps EXECUTE on patient_leaderboard_top10()'
);
select is(
  (select pronargs::int from pg_proc where oid = 'public.patient_leaderboard_top10()'::regprocedure),
  0,
  'patient_leaderboard_top10() takes no parameters (clinic comes only from the session)'
);
select ok(
  (select prosecdef from pg_proc where oid = 'public.patient_leaderboard_top10()'::regprocedure),
  'patient_leaderboard_top10() is still SECURITY DEFINER'
);
select is(
  (select proconfig from pg_proc where oid = 'public.patient_leaderboard_top10()'::regprocedure),
  array['search_path=pg_catalog, public']::text[],
  'patient_leaderboard_top10(): search_path is still pinned'
);

-- --- Result shape: no patient_id, has is_me --------------------------------
select is(
  (select array_agg(u.n order by u.o)
     from pg_proc p,
          lateral unnest(p.proargnames, p.proargmodes::text[]) with ordinality as u(n, m, o)
    where p.oid = 'public.patient_leaderboard_top10()'::regprocedure
      and u.m = 't'),
  array['name', 'avatar_url', 'league_xp', 'is_me']::text[],
  'result columns are exactly name, avatar_url, league_xp, is_me'
);
select ok(
  not exists (
    select 1 from pg_proc p
    where p.oid = 'public.patient_leaderboard_top10()'::regprocedure
      and 'patient_id' = any (p.proargnames)
  ),
  'result has no patient_id column'
);
select is(
  (select t.typname::text
     from pg_proc p
          cross join lateral unnest(p.proargnames, p.proargmodes::text[], p.proallargtypes) as u(n, m, typ)
          join pg_type t on t.oid = u.typ
    where p.oid = 'public.patient_leaderboard_top10()'::regprocedure
      and u.n = 'is_me'),
  'bool',
  'is_me is a boolean'
);

-- --- Fixtures (as the test owner; fictional) -------------------------------
-- Clinic A: a1001 (global fixture link) + a6002 (linked here).
-- Clinic B: b1001 (global fixture link).
-- a9001: has a patient_accounts row but no active link to any clinic.
insert into public.patient_record_links (
  app_user_id, org_id, telehealth_patient_id, status, linked_at, proof_method
) values (
  '00000000-0000-0000-0000-0000000a6002',
  '00000000-0000-0000-0000-00000000000a',
  'clinic:00000000-0000-0000-0000-0000000a6002',
  'active', now(), 'clinic_provisioned'
);

insert into public.patient_accounts (patient_id, name, league_xp) values
  ('00000000-0000-0000-0000-0000000a1001', 'Jordan Rivera', 50),
  ('00000000-0000-0000-0000-0000000a6002', '  Casey   Morgan lee ', 70),
  ('00000000-0000-0000-0000-0000000b1001', 'Riley', 999),
  ('00000000-0000-0000-0000-0000000a9001', 'Unlinked Fictional Person', 500);

-- --- Anonymous callers are refused ----------------------------------------
select tests.authenticate_as_anon();
select throws_ok(
  $$ select * from public.patient_leaderboard_top10() $$,
  '42501', null,
  'anon (explicit anon claim) is refused by patient_leaderboard_top10()'
);

select tests.clear_authentication();
select throws_ok(
  $$ select * from public.patient_leaderboard_top10() $$,
  '42501', null,
  'raw anon-key request with no claims is refused by patient_leaderboard_top10()'
);

-- --- Clinic A patient sees only clinic A ---------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2'); -- patient_a1

select throws_ok(
  $$ select patient_id from public.patient_leaderboard_top10() $$,
  '42703', null,
  'a signed-in caller cannot select patient_id from the leaderboard (no such column)'
);

select results_eq(
  $$ select name, league_xp from public.patient_leaderboard_top10() $$,
  $$ values ('Casey L.'::text, 70), ('Jordan R.'::text, 50) $$,
  'clinic A patient sees exactly the clinic A patients, ordered by league_xp desc'
);
select is(
  (select count(*)::int from public.patient_leaderboard_top10()
    where name = 'Riley' or league_xp = 999),
  0,
  'clinic A patient never sees a clinic B patient (even with higher league_xp)'
);
select is(
  (select count(*)::int from public.patient_leaderboard_top10()
    where name like 'Unlinked%' or league_xp = 500),
  0,
  'a patient with no active clinic link never appears on anyone''s leaderboard'
);

-- --- is_me: true for exactly the caller's own row --------------------------
select is(
  (select count(*)::int from public.patient_leaderboard_top10() where is_me),
  1,
  'patient_a1: exactly one row has is_me = true'
);
select is(
  (select name from public.patient_leaderboard_top10() where is_me),
  'Jordan R.',
  'patient_a1: the is_me row is the caller''s own row'
);
select is(
  (select is_me from public.patient_leaderboard_top10() where name = 'Casey L.'),
  false,
  'patient_a1: another clinic A patient''s row has is_me = false'
);
select is(
  (select count(*)::int from public.patient_leaderboard_top10() where is_me is null),
  0,
  'is_me is never null'
);

-- --- Names are first name + last initial ---------------------------------
-- (league_xp is unique per fixture row, so it pins the row without patient_id)
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 50),
  'Jordan R.',
  'two-part name comes back as first name + last initial'
);
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 70),
  'Casey L.',
  'multi-part, padded name comes back as first name + upper-cased last initial'
);
select ok(
  not exists (
    select 1 from public.patient_leaderboard_top10()
    where name ilike '%Rivera%' or name ilike '%Morgan%' or name ilike '%lee%'
  ),
  'no surname or middle name text is returned'
);

-- --- Clinic B patient sees only clinic B ---------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000b1001', 'aal2'); -- patient_b1
select results_eq(
  $$ select name, league_xp, is_me from public.patient_leaderboard_top10() $$,
  $$ values ('Riley'::text, 999, true) $$,
  'clinic B patient sees only clinic B (their own row, is_me = true); a single-word name is shown as-is'
);

-- patient a6002 (clinic A): is_me follows the caller, not a fixed row.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a6002', 'aal2');
select results_eq(
  $$ select name, is_me from public.patient_leaderboard_top10() $$,
  $$ values ('Casey L.'::text, true), ('Jordan R.'::text, false) $$,
  'patient_a2: is_me is true only on their own row, false on patient_a1''s'
);

-- --- Unlinked patient and staff get an empty list --------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a9001', 'aal2');
select is(
  (select count(*)::int from public.patient_leaderboard_top10()),
  0,
  'a signed-in user with no active clinic link gets an empty leaderboard'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select is(
  (select count(*)::int from public.patient_leaderboard_top10()),
  0,
  'clinic staff (org member, not a linked patient) get an empty leaderboard'
);

select * from finish();
rollback;
