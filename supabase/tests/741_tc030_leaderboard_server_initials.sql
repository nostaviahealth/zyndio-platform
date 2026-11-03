-- TC-030 item 9 server-side enforcement (Clara PR #29 H3):
-- patient_leaderboard_top10() must not leak OTHER patients' data to a signed-in
-- caller hitting the RPC directly. For every row that is not the caller:
--   * avatar_url must be NULL (no profile photos of other patients), and
--   * the display name is first name + last initial under the shared name rule,
--     or exactly 'Anonymous' - so an email-like value leaks no @/domain
--     fragment and a "Last, First" or NBSP-joined value leaks no surname.
-- The caller's own row keeps its own name and avatar. Clinic scope is unchanged
-- (a patient only ever sees their own clinic).
--
-- History: r1 (20261102164000) nulled other rows' avatars and formatted names;
-- r2/r3 (20261103110000) split tokens on anything not a letter/mark/number/
-- apostrophe and made any '@' 'Anonymous'.
--
-- PR #29 r5 (Clara r4 H1 + M1; Henry's REJECT rule; migration
-- 20261103123000_tc030_leaderboard_name_nfkc): applied identically here and in
-- the app (GamificationService._leaderboardNameParts):
--   a. NFKC first; b. NULL or any '@' -> 'Anonymous'; c. any
--   Default_Ignorable_Code_Point (full DerivedCoreProperties set) ->
--   'Anonymous'; d. any digit -> 'Anonymous'; e. only letters, marks, ASCII
--   space, ASCII '-', ' and U+2019 allowed, anything else -> 'Anonymous'
--   ((c) and (e) are checked on the stored value AND its NFKC form, so NBSP and
--   other compatibility spaces/symbols are rejected, not rewritten); f. an
--   apostrophe only between two letters/marks; g. spaces and hyphens split
--   (trim, collapse, drop empty pieces); h. first piece with its first letter
--   grapheme capitalised + ' ' + the last piece's first letter grapheme + '.',
--   one piece alone, 18-code-point cap.
--
-- Every shape from rounds 1-4 (Clara's r3 + r4 probe lists, every case of the
-- bbf14a0 Dart table and unit tests, and every name bbf14a0's 741 pinned) plus
-- the r5 additions is pinned below with the SAME expectation that
-- flutter_app/test/services/leaderboard_name_format_test.dart pins for the app.
-- Both tables are generated from one list
-- (work/.claude-runs/tc030h3r5/gen.py + ref_rule.py).
--
-- FAIL-FIRST: against bbf14a0's definition (20261103110000) the comma and NBSP
-- fixtures come back 'Quinn T.' (expected 'Anonymous'), the default-ignorable
-- sweep finds the Hangul fillers / CGJ / variation selectors / Khmer / tags
-- kept inside the name, and every changed shape fails its is() - see
-- work/.claude-runs/tc030h3r5/pgtap/741-failfirst.txt. Fictional data only.
begin;
select plan(478);

-- --- Fixtures (as the test owner; fictional) -------------------------------
-- Three extra clinic-A patients to exercise the leaky name shapes, plus the
-- global-fixture caller a1001 (clinic A) and b1001 (clinic B).
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
select
  '00000000-0000-0000-0000-000000000000',
  u.id, 'authenticated', 'authenticated', u.email,
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now()
from (values
  ('00000000-0000-0000-0000-0000000a6101'::uuid, 'patient-a6101@example.test'),
  ('00000000-0000-0000-0000-0000000a6102'::uuid, 'patient-a6102@example.test'),
  ('00000000-0000-0000-0000-0000000a6103'::uuid, 'patient-a6103@example.test')
) as u(id, email);

-- Active clinic-A links so the three extra patients appear on clinic A's board.
insert into public.patient_record_links (
  app_user_id, org_id, telehealth_patient_id, status, linked_at, proof_method
) values
  ('00000000-0000-0000-0000-0000000a6101', '00000000-0000-0000-0000-00000000000a',
     'clinic:00000000-0000-0000-0000-0000000a6101', 'active', now(), 'clinic_provisioned'),
  ('00000000-0000-0000-0000-0000000a6102', '00000000-0000-0000-0000-00000000000a',
     'clinic:00000000-0000-0000-0000-0000000a6102', 'active', now(), 'clinic_provisioned'),
  ('00000000-0000-0000-0000-0000000a6103', '00000000-0000-0000-0000-00000000000a',
     'clinic:00000000-0000-0000-0000-0000000a6103', 'active', now(), 'clinic_provisioned');

-- patient_accounts: every row carries a (fictional, in-bounds) image avatar, so
-- "avatar nulled for others / kept for me" is actually exercised. The NBSP name
-- joins the two words with a non-breaking space (chr(160)).
insert into public.patient_accounts (patient_id, name, avatar_url, league_xp) values
  ('00000000-0000-0000-0000-0000000a1001', 'Jordan Rivera',
     'data:image/png;base64,ZmljdGlvbmFsLWExMDAx', 100),
  ('00000000-0000-0000-0000-0000000a6101', 'Testcase, Quinn',
     'data:image/png;base64,ZmljdGlvbmFsLWE2MTAx', 90),
  ('00000000-0000-0000-0000-0000000a6102', 'quinn.testcase@example.test',
     'data:image/png;base64,ZmljdGlvbmFsLWE2MTAy', 80),
  ('00000000-0000-0000-0000-0000000a6103', 'Quinn' || chr(160) || 'Testcase',
     'data:image/png;base64,ZmljdGlvbmFsLWE2MTAz', 70),
  ('00000000-0000-0000-0000-0000000b1001', 'Riley Clinic-B',
     'data:image/png;base64,ZmljdGlvbmFsLWIxMDAx', 999);

-- --- The function itself ---------------------------------------------------
select ok(
  (select p.prosecdef from pg_proc p
     where p.oid = 'public.patient_leaderboard_top10()'::regprocedure),
  'H3 r5: patient_leaderboard_top10 is still SECURITY DEFINER'
);
select ok(
  (select 'search_path=pg_catalog, public' = any(p.proconfig) from pg_proc p
     where p.oid = 'public.patient_leaderboard_top10()'::regprocedure),
  'H3 r5: patient_leaderboard_top10 still pins search_path = pg_catalog, public'
);
select ok(
  not has_function_privilege('anon', 'public.patient_leaderboard_top10()', 'execute'),
  'H3 r5: anon has no EXECUTE on patient_leaderboard_top10'
);
select ok(
  not exists (
    select 1
    from pg_proc p, aclexplode(p.proacl) a
    where p.oid = 'public.patient_leaderboard_top10()'::regprocedure
      and a.grantee = 0 and a.privilege_type = 'EXECUTE'
  ),
  'H3 r5: PUBLIC has no EXECUTE on patient_leaderboard_top10'
);
select ok(
  has_function_privilege('authenticated', 'public.patient_leaderboard_top10()', 'execute'),
  'H3 r5: authenticated keeps EXECUTE on patient_leaderboard_top10'
);
select is(
  (select pg_encoding_to_char(encoding) from pg_database where datname = current_database()),
  'UTF8',
  'H3 r5: the database is UTF8 (normalize(.., NFKC) needs it)'
);

-- Default_Ignorable_Code_Point set (Unicode 17.0.0 DerivedCoreProperties, the
-- same 17 ranges as the migration and the app) as a bracket-expression body,
-- for the per-case "no default-ignorable code point in the output" checks.
create temp table lb_r5_di as select (chr(173) || '-' || chr(173) || chr(847) || '-' || chr(847) || chr(1564) || '-' || chr(1564) || chr(4447) || '-' || chr(4448) || chr(6068) || '-' || chr(6069) || chr(6155) || '-' || chr(6159) || chr(8203) || '-' || chr(8207) || chr(8234) || '-' || chr(8238) || chr(8288) || '-' || chr(8303) || chr(12644) || '-' || chr(12644) || chr(65024) || '-' || chr(65039) || chr(65279) || '-' || chr(65279) || chr(65440) || '-' || chr(65440) || chr(65520) || '-' || chr(65528) || chr(113824) || '-' || chr(113827) || chr(119155) || '-' || chr(119162) || chr(917504) || '-' || chr(921599)) as di_chars;
grant select on pg_temp.lb_r5_di to authenticated;

-- --- Caller: clinic-A patient a1001 (own row) ------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');

-- Own row keeps the caller's own name and avatar.
select is(
  (select name from public.patient_leaderboard_top10() where is_me),
  'Jordan R.',
  'H3: the caller''s own row shows their own name'
);
select ok(
  (select avatar_url from public.patient_leaderboard_top10() where is_me) is not null,
  'H3: the caller''s own row keeps its avatar_url'
);

-- Every OTHER row drops the avatar entirely.
select is(
  (select count(*)::int from public.patient_leaderboard_top10()
     where not is_me and avatar_url is not null),
  0,
  'H3: no other patient''s avatar_url is returned (all NULL)'
);

-- "Last, First" -> 'Anonymous' under the r5 reject rule (',' is not allowed);
-- the surname never leaks.
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 90),
  'Anonymous',
  'H3 r5: a "Last, First" name (comma) is shown as Anonymous'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 90)
    not ilike '%Testcase%',
  'H3: the "Last, First" row leaks no surname'
);

-- Email-like name -> exactly 'Anonymous'; no @, no domain and no surname.
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3: an email-like name is shown as Anonymous'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3: an email-like name leaks no surname from its local part'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not like '%@%',
  'H3: an email-like name leaks no @'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%example%',
  'H3: an email-like name leaks no domain fragment'
);

-- NBSP-joined name -> 'Anonymous' under the r5 reject rule (NBSP is not an
-- allowed character, even though NFKC maps it to a space); no full name leaks.
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 70),
  'Anonymous',
  'H3 r5: an NBSP-joined name is shown as Anonymous'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 70)
    not ilike '%Testcase%',
  'H3: the NBSP-joined row leaks no full surname'
);

-- --- Default_Ignorable_Code_Point sweep (rule c) ---------------------------
-- 'Quinn' || <cp> || 'Testcase' for the first, middle and last code point of
-- each of the 17 ranges must be exactly 'Anonymous'. Returns the code points
-- that are NOT (expected: none).
reset role;
create function pg_temp.lb_r5_di_sweep() returns int[] language plpgsql as $f$
declare cp int; got text; bad int[] := '{}';
begin
  foreach cp in array array[173,847,1564,4447,4448,6068,6069,6155,6157,6159,8203,8205,8207,8234,8236,8238,8288,8295,8303,12644,65024,65031,65039,65279,65440,65520,65524,65528,113824,113825,113827,119155,119158,119162,917504,919551,921599] loop
    update public.patient_accounts set name = 'Quinn' || chr(cp) || 'Testcase'
     where patient_id = '00000000-0000-0000-0000-0000000a6102';
    perform tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
    select t.name into got from public.patient_leaderboard_top10() t where t.league_xp = 80;
    perform set_config('role', 'none', true);
    if got is distinct from 'Anonymous' then bad := bad || cp; end if;
  end loop;
  return bad;
end $f$;
select is(
  pg_temp.lb_r5_di_sweep(),
  '{}'::int[],
  'H3 r5 (c): every Default_Ignorable_Code_Point range (start, middle, end; 37 code points) gives Anonymous'
);

-- --- Every round 1-5 name shape (same table as the Dart test) --------------
-- Each case rewrites the a6102 row's name as the test owner, then reads it back
-- as the clinic-A caller.
reset role;
update public.patient_accounts set name = 'Testcase, Quinn'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [comma] Testcase, Quinn -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [comma] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [comma] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Testcase,Quinn'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [comma-nospace] Testcase,Quinn -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [comma-nospace] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [comma-nospace] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'quinn.testcase@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [email] quinn.testcase@example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [email] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [email] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'quinn_testcase@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [email-underscore] quinn_testcase@example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [email-underscore] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [email-underscore] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'qtestcase@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [email-plain] qtestcase@example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [email-plain] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [email-plain] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(160) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [nbsp] Quinn<U+00A0>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [nbsp] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [nbsp] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(9) || chr(10) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [tab-newline] Quinn<U+0009><U+000A>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [tab-newline] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [tab-newline] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn',
  'H3 r5 [single] Quinn -> Quinn'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [single] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Quinn Avery Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r5 [three-words] Quinn Avery Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [three-words] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [three-words] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn ' || chr(129412) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [emoji] Quinn <U+1F984>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [emoji] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [emoji] leaks no surname'
);
reset role;
update public.patient_accounts set name = chr(129412) || ' Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [emoji-first] <U+1F984> Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [emoji-first] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [emoji-first] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Zo' || chr(235) || ' ' || chr(197) || 'ngstr' || chr(246) || 'm'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Zo' || chr(235) || ' ' || chr(197) || '.',
  'H3 r5 [unicode] Zo<U+00EB> <U+00C5>ngstr<U+00F6>m -> Zo<U+00EB> <U+00C5>.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [unicode] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8203) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [zwsp] Quinn<U+200B>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [zwsp] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [zwsp] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8195) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [emspace] Quinn<U+2003>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [emspace] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [emspace] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(12288) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [ideographic] Quinn<U+3000>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [ideographic] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [ideographic] leaks no surname'
);
reset role;
update public.patient_accounts set name = ''
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [empty]  -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [empty] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = '   '
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [whitespace]     -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [whitespace] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = chr(160) || chr(160)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [nbsp-only] <U+00A0><U+00A0> -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [nbsp-only] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Quinn.Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [dot-local] Quinn.Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [dot-local] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [dot-local] leaks no surname'
);
reset role;
update public.patient_accounts set name = '@testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [at-first] @testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [at-first] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [at-first] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinnabellarosalind Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinnabellarosalin',
  'H3 r5 [long] Quinnabellarosalind Testcase -> Quinnabellarosalin'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [long] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [long] leaks no surname'
);
reset role;
update public.patient_accounts set name = NULL
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [null] NULL -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [null] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'quinn-testcase@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [email-hyphen] quinn-testcase@example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [email-hyphen] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [email-hyphen] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'QUINN.TESTCASE@EXAMPLE.TEST'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [email-upper] QUINN.TESTCASE@EXAMPLE.TEST -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [email-upper] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [email-upper] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'quinn+testcase@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [email-plus] quinn+testcase@example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [email-plus] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [email-plus] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'quinn.t+clinic@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [email-plus-dot] quinn.t+clinic@example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [email-plus-dot] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'quinn.testcase@foo@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [multi-at] quinn.testcase@foo@example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [multi-at] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [multi-at] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'quinn@testcase@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [multi-at2] quinn@testcase@example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [multi-at2] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [multi-at2] leaks no surname'
);
reset role;
update public.patient_accounts set name = '_quinn.testcase_'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [lead-trail-sep] _quinn.testcase_ -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [lead-trail-sep] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [lead-trail-sep] leaks no surname'
);
reset role;
update public.patient_accounts set name = '.testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [lead-dot-surname] .testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [lead-dot-surname] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [lead-dot-surname] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'testcase.'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [trail-dot] testcase. -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [trail-dot] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [trail-dot] leaks no surname'
);
reset role;
update public.patient_accounts set name = '.testcase@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [dot-only-surname-email] .testcase@example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [dot-only-surname-email] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [dot-only-surname-email] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8204) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [zwnj] Quinn<U+200C>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [zwnj] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [zwnj] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8205) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [zwj] Quinn<U+200D>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [zwj] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [zwj] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8288) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [wj] Quinn<U+2060>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [wj] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [wj] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(65279) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [bom] Quinn<U+FEFF>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [bom] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [bom] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(173) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [soft-hyphen] Quinn<U+00AD>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [soft-hyphen] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [soft-hyphen] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8206) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [lrm] Quinn<U+200E>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [lrm] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [lrm] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8207) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [rlm] Quinn<U+200F>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [rlm] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [rlm] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(6158) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [mongolian-vs] Quinn<U+180E>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [mongolian-vs] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [mongolian-vs] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8290) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [invisible-times] Quinn<U+2062>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [invisible-times] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [invisible-times] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8238) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [rlo-joined] Quinn<U+202E>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [rlo-joined] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [rlo-joined] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn ' || chr(8238) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [rlo-word] Quinn <U+202E>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [rlo-word] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [rlo-word] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Que' || chr(769) || 'nn Te' || chr(769) || 'stcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Qu' || chr(233) || 'nn T.',
  'H3 r5 [combining] Que<U+0301>nn Te<U+0301>stcase -> Qu<U+00E9>nn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [combining] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Quinn ' || chr(769) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r5 [combining-lead] Quinn <U+0301>Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [combining-lead] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [combining-lead] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'QQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQ TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'QQQQQQQQQQQQQQQQQQ',
  'H3 r5 [very-long] QQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQ TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT -> QQQQQQQQQQQQQQQQQQ'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [very-long] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Quinnabellarosalindevangeline.Testcasesmithington'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [very-long-joined] Quinnabellarosalindevangeline.Testcasesmithington -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [very-long-joined] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [very-long-joined] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn2 Testcase99'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [digits] Quinn2 Testcase99 -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [digits] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [digits] leaks no surname'
);
reset role;
update public.patient_accounts set name = '12345'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [digits-only] 12345 -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [digits-only] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Dr. Quinn Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [honorific] Dr. Quinn Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [honorific] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [honorific] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn Testcase-Smith'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn S.',
  'H3 r5 [hyphen-surname] Quinn Testcase-Smith -> Quinn S.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [hyphen-surname] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [hyphen-surname] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Testcase-Smith, Quinn'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [hyphen-comma] Testcase-Smith, Quinn -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [hyphen-comma] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [hyphen-comma] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'qtestcase@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [handle-email] qtestcase@example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [handle-email] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [handle-email] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'QuinnTestcase@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [camel-email] QuinnTestcase@example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [camel-email] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [camel-email] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'qtestcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Qtestcase',
  'H3 r5 [plain-handle] qtestcase -> Qtestcase'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [plain-handle] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(129412) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [emoji-joined] Quinn<U+1F984>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [emoji-joined] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [emoji-joined] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8201) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [thin-space] Quinn<U+2009>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [thin-space] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [thin-space] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8232) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [line-sep] Quinn<U+2028>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [line-sep] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [line-sep] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Testcase, Quinn@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [comma-email] Testcase, Quinn@example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [comma-email] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [comma-email] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'quinn+testcase@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [plus2] quinn+testcase@example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [plus2] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [plus2] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'qtestcase@'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [handle-at] qtestcase@ -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [handle-at] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [handle-at] leaks no surname'
);
reset role;
update public.patient_accounts set name = '@testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [at-handle] @testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [at-handle] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [at-handle] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'a@b'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [a@b] a@b -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [a@b] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'qtestcase' || chr(65312) || 'example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [fullwidth-at] qtestcase<U+FF20>example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [fullwidth-at] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [fullwidth-at] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'quinn.testcase' || chr(65312) || 'example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [fullwidth-at-dot] quinn.testcase<U+FF20>example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [fullwidth-at-dot] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [fullwidth-at-dot] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'qtestcase' || chr(65131) || 'example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [small-at] qtestcase<U+FE6B>example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [small-at] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [small-at] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'quinn.testcase' || chr(65131) || 'example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [small-at-dot] quinn.testcase<U+FE6B>example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [small-at-dot] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [small-at-dot] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'qtestcase' || chr(9424) || 'example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [at-lookalike-2148] qtestcase<U+24D0>example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [at-lookalike-2148] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [at-lookalike-2148] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'qtestcase at example dot test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Qtestcase T.',
  'H3 r5 [email-no-at-spaced] qtestcase at example dot test -> Qtestcase T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [email-no-at-spaced] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Quinn ' || chr(1058) || 'estcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn ' || chr(1058) || '.',
  'H3 r5 [homoglyph-cyrillic] Quinn <U+0422>estcase -> Quinn <U+0422>.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [homoglyph-cyrillic] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [homoglyph-cyrillic] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Qu' || chr(1110) || 'nn T' || chr(1077) || 'stcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Qu' || chr(1110) || 'nn T.',
  'H3 r5 [homoglyph-latin-cyr-mix] Qu<U+0456>nn T<U+0435>stcase -> Qu<U+0456>nn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [homoglyph-latin-cyr-mix] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = chr(1497) || chr(1506) || chr(1500) || ' ' || chr(1499) || chr(1492) || chr(1503)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  chr(1497) || chr(1506) || chr(1500) || ' ' || chr(1499) || '.',
  'H3 r5 [hebrew] <U+05D9><U+05E2><U+05DC> <U+05DB><U+05D4><U+05DF> -> <U+05D9><U+05E2><U+05DC> <U+05DB>.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [hebrew] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = chr(1604) || chr(1614) || chr(1610) || chr(1618) || chr(1604) || chr(1614) || chr(1609) || ' ' || chr(1581) || chr(1614) || chr(1587) || chr(1614) || chr(1606)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  chr(1604) || chr(1614) || chr(1610) || chr(1618) || chr(1604) || chr(1614) || chr(1609) || ' ' || chr(1581) || chr(1614) || '.',
  'H3 r5 [arabic] <U+0644><U+064E><U+064A><U+0652><U+0644><U+064E><U+0649> <U+062D><U+064E><U+0633><U+064E><U+0646> -> <U+0644><U+064E><U+064A><U+0652><U+0644><U+064E><U+0649> <U+062D><U+064E>.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [arabic] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = chr(2309) || chr(2344) || chr(2367) || chr(2340) || chr(2366) || ' ' || chr(2358) || chr(2352) || chr(2381) || chr(2350) || chr(2366)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  chr(2309) || chr(2344) || chr(2367) || chr(2340) || chr(2366) || ' ' || chr(2358) || '.',
  'H3 r5 [devanagari] <U+0905><U+0928><U+093F><U+0924><U+093E> <U+0936><U+0930><U+094D><U+092E><U+093E> -> <U+0905><U+0928><U+093F><U+0924><U+093E> <U+0936>.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [devanagari] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = chr(29579) || ' ' || chr(23567) || chr(26126)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  chr(29579) || ' ' || chr(23567) || '.',
  'H3 r5 [cjk] <U+738B> <U+5C0F><U+660E> -> <U+738B> <U+5C0F>.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [cjk] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = chr(29579) || chr(23567) || chr(26126)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  chr(29579) || chr(23567) || chr(26126),
  'H3 r5 [cjk-joined] <U+738B><U+5C0F><U+660E> -> <U+738B><U+5C0F><U+660E>'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [cjk-joined] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = chr(3626) || chr(3617) || chr(3594) || chr(3634) || chr(3618) || ' ' || chr(3651) || chr(3592) || chr(3604) || chr(3637)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  chr(3626) || chr(3617) || chr(3594) || chr(3634) || chr(3618) || ' ' || chr(3651) || '.',
  'H3 r5 [thai] <U+0E2A><U+0E21><U+0E0A><U+0E32><U+0E22> <U+0E43><U+0E08><U+0E14><U+0E35> -> <U+0E2A><U+0E21><U+0E0A><U+0E32><U+0E22> <U+0E43>.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [thai] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = '2024 1999'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [all-digits] 2024 1999 -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [all-digits] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = ''''''
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [apostrophe-only] '''' -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [apostrophe-only] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = chr(8217) || chr(8217)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [rsquo-only] <U+2019><U+2019> -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [rsquo-only] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Quinn O''Brien'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn O.',
  'H3 r5 [obrien] Quinn O''Brien -> Quinn O.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [obrien] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'O''Brien'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'O''Brien',
  'H3 r5 [obrien-only] O''Brien -> O''Brien'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [obrien-only] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Quinn''Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn''Testcase',
  'H3 r5 [apostrophe-joined] Quinn''Testcase -> Quinn''Testcase'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [apostrophe-joined] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Quinn1Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [digit-joined] Quinn1Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [digit-joined] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [digit-joined] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinnabellarosalindevangelinemarigold Testcasesmithingtonworthshire-Jones'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinnabellarosalin',
  'H3 r5 [long80] Quinnabellarosalindevangelinemarigold Testcasesmithingtonworthshire-Jones -> Quinnabellarosalin'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [long80] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [long80] leaks no surname'
);
reset role;
update public.patient_accounts set name = NULL
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [null2] NULL -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [null2] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = ','
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [comma-only] , -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [comma-only] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Testcase, Quinn, Jr'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [multi-comma] Testcase, Quinn, Jr -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [multi-comma] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [multi-comma] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(12644) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [hangul-filler-3164] Quinn<U+3164>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [hangul-filler-3164] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [hangul-filler-3164] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(4448) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [hangul-jungseong-1160] Quinn<U+1160>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [hangul-jungseong-1160] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [hangul-jungseong-1160] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(4447) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [hangul-choseong-115F] Quinn<U+115F>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [hangul-choseong-115F] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [hangul-choseong-115F] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(65440) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [halfwidth-hangul-FFA0] Quinn<U+FFA0>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [halfwidth-hangul-FFA0] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [halfwidth-hangul-FFA0] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(847) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [cgj-034F] Quinn<U+034F>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [cgj-034F] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [cgj-034F] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(65039) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [vs16-FE0F] Quinn<U+FE0F>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [vs16-FE0F] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [vs16-FE0F] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(917760) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [vs-supp-E0100] Quinn<U+E0100>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [vs-supp-E0100] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [vs-supp-E0100] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(6155) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [mongolian-fvs-180B] Quinn<U+180B>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [mongolian-fvs-180B] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [mongolian-fvs-180B] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(6068) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [khmer-17B4] Quinn<U+17B4>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [khmer-17B4] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [khmer-17B4] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(769) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quin' || chr(324) || 'Testcase',
  'H3 r5 [combining-joiner-0301] Quinn<U+0301>Testcase -> Quin<U+0144>Testcase'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [combining-joiner-0301] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(917569) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [tag-chars-E0041] Quinn<U+E0041>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [tag-chars-E0041] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [tag-chars-E0041] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(10240) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [braille-blank-2800] Quinn<U+2800>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [braille-blank-2800] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [braille-blank-2800] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn ' || chr(128104) || chr(8205) || chr(128105) || ' Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [emoji-zwj-seq] Quinn <U+1F468><U+200D><U+1F469> Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [emoji-zwj-seq] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [emoji-zwj-seq] leaks no surname'
);
reset role;
update public.patient_accounts set name = chr(769) || 'Quinn ' || chr(769) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r5 [mark-lead-piece] <U+0301>Quinn <U+0301>Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [mark-lead-piece] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [mark-lead-piece] leaks no surname'
);
reset role;
update public.patient_accounts set name = chr(8238) || 'Quinn Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [rlo-lead] <U+202E>Quinn Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [rlo-lead] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [rlo-lead] leaks no surname'
);
reset role;
update public.patient_accounts set name = '9Quinn 7Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [digit-lead-piece] 9Quinn 7Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [digit-lead-piece] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [digit-lead-piece] leaks no surname'
);
reset role;
update public.patient_accounts set name = chr(65329) || chr(65365) || chr(65353) || chr(65358) || chr(65358) || ' ' || chr(65332) || chr(65349) || chr(65363) || chr(65364)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r5 [fullwidth-letters] <U+FF31><U+FF55><U+FF49><U+FF4E><U+FF4E> <U+FF34><U+FF45><U+FF53><U+FF54> -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [fullwidth-letters] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Se' || chr(225) || 'n O''Brien'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Se' || chr(225) || 'n O.',
  'H3 r5 [apostrophe-surname] Se<U+00E1>n O''Brien -> Se<U+00E1>n O.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [apostrophe-surname] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'd''Arcy Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'D''Arcy T.',
  'H3 r5 [apostrophe-lead] d''Arcy Testcase -> D''Arcy T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [apostrophe-lead] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [apostrophe-lead] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn ' || chr(8217) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [curly-apostrophe-lead] Quinn <U+2019>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [curly-apostrophe-lead] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [curly-apostrophe-lead] leaks no surname'
);
reset role;
update public.patient_accounts set name = chr(2346) || chr(2381) || chr(2352) || chr(2367) || chr(2351) || chr(2366) || ' ' || chr(2358) || chr(2352) || chr(2381) || chr(2350) || chr(2366)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  chr(2346) || chr(2381) || chr(2352) || chr(2367) || chr(2351) || chr(2366) || ' ' || chr(2358) || '.',
  'H3 r5 [devanagari-conjunct] <U+092A><U+094D><U+0930><U+093F><U+092F><U+093E> <U+0936><U+0930><U+094D><U+092E><U+093E> -> <U+092A><U+094D><U+0930><U+093F><U+092F><U+093E> <U+0936>.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [devanagari-conjunct] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'e' || chr(769) || 'mile Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  chr(201) || 'mile T.',
  'H3 r5 [decomposed-first] e<U+0301>mile Testcase -> <U+00C9>mile T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [decomposed-first] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [decomposed-first] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn ' || chr(1633) || chr(1634)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [arabic-digit-token] Quinn <U+0661><U+0662> -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [arabic-digit-token] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Quinn 2Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [digit-led-surname] Quinn 2Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [digit-led-surname] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [digit-led-surname] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn ' || chr(769) || chr(769)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn',
  'H3 r5 [mark-only-token] Quinn <U+0301><U+0301> -> Quinn'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [mark-only-token] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = chr(8238) || chr(8238)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [rlo-only] <U+202E><U+202E> -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [rlo-only] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'quinn testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r5 [lowercase-two] quinn testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [lowercase-two] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [lowercase-two] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'qtestcase@'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [handle-no-dot] qtestcase@ -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [handle-no-dot] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [handle-no-dot] leaks no surname'
);
reset role;
update public.patient_accounts set name = '@'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [at-only] @ -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [at-only] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Quinn+Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [plus-joined] Quinn+Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [plus-joined] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [plus-joined] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn ' || chr(119808) || 'bc'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn A.',
  'H3 r5 [astral-letter-initial] Quinn <U+1D400>bc -> Quinn A.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [astral-letter-initial] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Quinn-Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r5 [r5-hyphen-joined] Quinn-Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-hyphen-joined] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [r5-hyphen-joined] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Mary-Jane O''Neil'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Mary O.',
  'H3 r5 [r5-hyphen-double-barrel] Mary-Jane O''Neil -> Mary O.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-hyphen-double-barrel] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = '  Quinn  --  Testcase  '
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r5 [r5-runs-of-separators]   Quinn  --  Testcase   -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-runs-of-separators] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [r5-runs-of-separators] leaks no surname'
);
reset role;
update public.patient_accounts set name = '-Quinn'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn',
  'H3 r5 [r5-leading-hyphen] -Quinn -> Quinn'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-leading-hyphen] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = '-'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-hyphen-only] - -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-hyphen-only] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Quinn -'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn',
  'H3 r5 [r5-trailing-hyphen-piece] Quinn - -> Quinn'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-trailing-hyphen-piece] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Quinn O' || chr(8217) || 'Brien'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn O.',
  'H3 r5 [r5-rsquo-inside] Quinn O<U+2019>Brien -> Quinn O.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-rsquo-inside] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = '''Quinn Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-apostrophe-leading] ''Quinn Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-apostrophe-leading] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [r5-apostrophe-leading] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn Testcase'''
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-apostrophe-trailing] Quinn Testcase'' -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-apostrophe-trailing] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [r5-apostrophe-trailing] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn O''''Brien'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-apostrophe-doubled] Quinn O''''Brien -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-apostrophe-doubled] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Quinn ''Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-apostrophe-after-space] Quinn ''Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-apostrophe-after-space] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [r5-apostrophe-after-space] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Que' || chr(769) || '''nn Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Qu' || chr(233) || '''nn T.',
  'H3 r5 [r5-apostrophe-after-mark] Que<U+0301>''nn Testcase -> Qu<U+00E9>''nn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-apostrophe-after-mark] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [r5-apostrophe-after-mark] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(6069) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-di-17B5] Quinn<U+17B5>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-di-17B5] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [r5-di-17B5] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(6159) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-di-180F] Quinn<U+180F>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-di-180F] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [r5-di-180F] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(65024) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-di-FE00] Quinn<U+FE00>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-di-FE00] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [r5-di-FE00] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(917999) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-di-E01EF] Quinn<U+E01EF>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-di-E01EF] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [r5-di-E01EF] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(1564) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-di-061C-alm] Quinn<U+061C>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-di-061C-alm] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [r5-di-061C-alm] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8292) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-di-2064] Quinn<U+2064>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-di-2064] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [r5-di-2064] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8303) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-di-206F] Quinn<U+206F>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-di-206F] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [r5-di-206F] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(113824) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-di-1BCA0] Quinn<U+1BCA0>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-di-1BCA0] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [r5-di-1BCA0] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(119155) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-di-1D173] Quinn<U+1D173>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-di-1D173] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [r5-di-1D173] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(65520) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-di-FFF0-unassigned] Quinn<U+FFF0>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-di-FFF0-unassigned] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [r5-di-FFF0-unassigned] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(917505) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-di-E0001-tag] Quinn<U+E0001>Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-di-E0001-tag] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [r5-di-E0001-tag] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn Testcase' || chr(12644)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-di-3164-trailing] Quinn Testcase<U+3164> -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-di-3164-trailing] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [r5-di-3164-trailing] leaks no surname'
);
reset role;
update public.patient_accounts set name = chr(12644)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-di-3164-only] <U+3164> -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-di-3164-only] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(65039) || ' Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-di-vs16-after-word] Quinn<U+FE0F> Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-di-vs16-after-word] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [r5-di-vs16-after-word] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(65312)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-nfkc-fullwidth-at-only] Quinn<U+FF20> -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-nfkc-fullwidth-at-only] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = chr(64257) || 'ona Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Fiona T.',
  'H3 r5 [r5-nfkc-ligature-fi] <U+FB01>ona Testcase -> Fiona T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-nfkc-ligature-fi] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [r5-nfkc-ligature-fi] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'e' || chr(769) || 'mile Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  chr(201) || 'mile T.',
  'H3 r5 [r5-nfkc-composes-e-acute] e<U+0301>mile Testcase -> <U+00C9>mile T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-nfkc-composes-e-acute] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [r5-nfkc-composes-e-acute] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn ' || chr(9424)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-circled-a-word] Quinn <U+24D0> -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-circled-a-word] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(178)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-superscript-two] Quinn<U+00B2> -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-superscript-two] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Quinn ' || chr(8551)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-roman-numeral] Quinn <U+2167> -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-roman-numeral] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8482)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-trademark] Quinn<U+2122> -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-trademark] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Quinn.'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-dot-trailing] Quinn. -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-dot-trailing] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Jordan R.'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-already-formatted] Jordan R. -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-already-formatted] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(12288) || 'Testcase' || chr(12288) || 'Jr'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r5-fullwidth-space] Quinn<U+3000>Testcase<U+3000>Jr -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-fullwidth-space] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [r5-fullwidth-space] leaks no surname'
);
reset role;
update public.patient_accounts set name = chr(44608) || ' ' || chr(48124) || chr(51456)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  chr(44608) || ' ' || chr(48124) || '.',
  'H3 r5 [r5-hangul-name] <U+AE40> <U+BBFC><U+C900> -> <U+AE40> <U+BBFC>.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r5-hangul-name] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Jordan Rivera'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Jordan R.',
  'H3 r5 [r1-unit-02] Jordan Rivera -> Jordan R.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r1-unit-02] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = '  Jordan Rivera  '
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Jordan R.',
  'H3 r5 [r1-unit-03]   Jordan Rivera   -> Jordan R.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r1-unit-03] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Jordan' || chr(160) || 'Rivera'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r1-unit-04] Jordan<U+00A0>Rivera -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r1-unit-04] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Jordan' || chr(9) || chr(10) || ' ' || chr(160) || 'Rivera'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r1-unit-05] Jordan<U+0009><U+000A> <U+00A0>Rivera -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r1-unit-05] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Rivera, Jordan'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r1-unit-06] Rivera, Jordan -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r1-unit-06] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Riley'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Riley',
  'H3 r5 [r1-unit-07] Riley -> Riley'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r1-unit-07] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'jordan.rivera@example.com'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r1-unit-08] jordan.rivera@example.com -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r1-unit-08] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'jordan.rivera'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r1-unit-09] jordan.rivera -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r1-unit-09] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'morgan_lee'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r1-unit-10] morgan_lee -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r1-unit-10] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = chr(8203) || chr(8203)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r1-unit-16] <U+200B><U+200B> -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r1-unit-16] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Quinn ' || chr(129412) || '.'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r1-unit-22] Quinn <U+1F984>. -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r1-unit-22] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = chr(129412) || 'Quinn Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r1-unit-24] <U+1F984>Quinn Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r1-unit-24] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [r1-unit-24] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinnabellarosali' || chr(129412) || chr(129412) || ' Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r1-unit-25] Quinnabellarosali<U+1F984><U+1F984> Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r1-unit-25] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [r1-unit-25] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Maximiliana Wolfeschlegelstein'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Maximiliana W.',
  'H3 r5 [r1-unit-26] Maximiliana Wolfeschlegelstein -> Maximiliana W.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r1-unit-26] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Riley' || chr(9) || 'Smith' || chr(10) || 'Jones'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r1-unit-28] Riley<U+0009>Smith<U+000A>Jones -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r1-unit-28] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = chr(129412)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r1-unit-30] <U+1F984> -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r1-unit-30] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'blake'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Blake',
  'H3 r5 [r1-unit-31] blake -> Blake'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r1-unit-31] no @, no U+FFFD, no default-ignorable code point'
);
reset role;
update public.patient_accounts set name = 'Quinn_Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r5 [r2-underscore-joined] Quinn_Testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r2-underscore-joined] no @, no U+FFFD, no default-ignorable code point'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r5 [r2-underscore-joined] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'quinn'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn',
  'H3 r5 [r2-lowercase-single] quinn -> Quinn'
);
select ok(
  (select name !~ ('[@' || chr(65533) || di_chars || ']')
     from public.patient_leaderboard_top10(), pg_temp.lb_r5_di where league_xp = 80),
  'H3 r5 [r2-lowercase-single] no @, no U+FFFD, no default-ignorable code point'
);

-- Clinic scope unchanged: the clinic-B patient never appears here.
select is(
  (select count(*)::int from public.patient_leaderboard_top10()
     where league_xp = 999 or name ilike '%Riley%'),
  0,
  'H3: a clinic-A caller never sees the clinic-B patient'
);

-- --- Caller: clinic-B patient b1001 (own row, other clinic) ----------------
-- 'Riley Clinic-B': the hyphen splits, so the last piece is 'B'.
select tests.authenticate_as('00000000-0000-0000-0000-0000000b1001', 'aal2');
select results_eq(
  $$ select name, is_me, (avatar_url is not null) from public.patient_leaderboard_top10() $$,
  $$ values ('Riley B.'::text, true, true) $$,
  'H3: the clinic-B caller sees only their own clinic-B row, with their own name and avatar'
);
select is(
  (select count(*)::int from public.patient_leaderboard_top10()
     where name ilike '%Quinn%' or name ilike '%Jordan%'),
  0,
  'H3: the clinic-B caller never sees any clinic-A patient'
);

select * from finish();
rollback;
