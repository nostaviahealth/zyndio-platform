-- TC-030 item 9 server-side enforcement (Clara PR #29 H3):
-- patient_leaderboard_top10() must not leak OTHER patients' data to a signed-in
-- caller hitting the RPC directly. For every row that is not the caller:
--   * avatar_url must be NULL (no profile photos of other patients), and
--   * the display name must be the robustly-formatted "First L." - so an
--     email-like value leaks no @/domain fragment, a "Last, First" value leaks
--     no surname, and an NBSP-joined value leaks no full name.
-- The caller's own row keeps its own name and avatar. Clinic scope is unchanged
-- (a patient only ever sees their own clinic).
--
-- This encodes the hands-on probe from PR #29
-- (hands-on/leaderboard-rpc-probe.txt), where the HEAD-before-this-fix function
-- returned, for other clinic-A patients: name="Testcase, Q." avatar_present=t,
-- the full email "quinn.testcase@example.test", and the NBSP full name
-- "Quinn Testcase".
--
-- H3 follow-up (Clara PR #29 r2): the email-like row must now come back as
-- "Quinn T." (the server splits a lone [._-]-joined token as the app does), and
-- the extra shapes below (underscore/hyphen email, dot-joined, zero-width
-- joined, single, emoji, empty/blank, "@handle") are pinned. Against the
-- 28dc43a definition the email/dot/underscore/hyphen/zero-width cases, the
-- lower-case single name and "@testcase" fail.
--
-- H3 r3 (Clara PR #29 r3, Henry's ruling; migration 20261103110000): a name is
-- NEVER built from an email or handle - any value with '@' (and NULL) is exactly
-- 'Anonymous'; otherwise tokens split on anything that is not a letter, mark,
-- number or apostrophe, each token starts at its first letter, and the result
-- is first name + last initial (one token -> first name alone; none ->
-- 'Anonymous'). So the email row (a6102) and the email/handle shapes now expect
-- 'Anonymous' (they expected 'Quinn T.' at 3fc5f75), the emoji-led surname
-- expects 'Quinn T.' (was 'Quinn <emoji>.'), the emoji-leading name expects
-- 'Quinn T.' (was '<emoji>Quinn T.'), and the hyphenated clinic-B name
-- 'Riley Clinic-B' expects 'Riley B.' (was 'Riley C.'). Every shape from Clara's
-- r3 probe (hands-on/leaderboard-rpc-probe-HEAD.txt) is pinned below with the
-- value the app's GamificationService.formatLeaderboardName gives for the same
-- input (flutter_app/test/services/leaderboard_name_format_test.dart pins the
-- same table).
--
-- FAIL-FIRST (run without migration 20261102164000): the prior definition
-- (20261102130000_tc026_leaderboard_is_me.sql) returns a.avatar_url for ALL
-- rows (so every "other row has a null avatar" and "no other row keeps an
-- avatar" assertion fails), and splits names on whitespace only - so the comma
-- name comes back as "Testcase, Q." (fails the no-surname check), the email
-- name comes back in full as "quinn.testcase@example.test" (fails the no-@ /
-- no-domain checks), and the NBSP name comes back as the full "Quinn Testcase"
-- (fails the "Quinn T." check). Fictional data only.
begin;
select no_plan();

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

-- "Last, First" -> "First L."; the surname never leaks.
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 90),
  'Quinn T.',
  'H3: a "Last, First" name is reduced to first name + last initial'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 90)
    not ilike '%Testcase%',
  'H3: the "Last, First" row leaks no surname'
);

-- Email-like name -> exactly 'Anonymous' (H3 r3: never built from an email);
-- no @, no domain and no surname.
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

-- NBSP-joined name splits into "First L."; the full name never leaks.
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 70),
  'Quinn T.',
  'H3: an NBSP-joined name is split into first name + last initial'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 70)
    not ilike '%Testcase%',
  'H3: the NBSP-joined row leaks no full surname'
);


-- --- H3 follow-up (Clara PR #29 r2): more name shapes ----------------------
-- Each case rewrites the a6102 row's name as the test owner, then reads it back
-- as the clinic-A caller. Expected values match the Flutter client's
-- GamificationService.formatLeaderboardName for the same input. Characters are
-- whole code points, so an emoji is never split (no U+FFFD).
reset role;
update public.patient_accounts set name = 'quinn_testcase@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3: an underscore email local part -> ' || 'Anonymous'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3: an underscore email local part leaks no surname'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not like '%@%',
  'H3: an underscore email local part leaks no @'
);
reset role;
update public.patient_accounts set name = 'quinn-testcase@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3: a hyphen email local part -> ' || 'Anonymous'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3: a hyphen email local part leaks no surname'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not like '%@%',
  'H3: a hyphen email local part leaks no @'
);
reset role;
update public.patient_accounts set name = 'Quinn.Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3: a dot-joined name -> ' || 'Quinn T.'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3: a dot-joined name leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn_Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3: an underscore-joined name -> ' || 'Quinn T.'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3: an underscore-joined name leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8203) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3: a zero-width-space (U+200B) joined name -> ' || 'Quinn T.'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3: a zero-width-space (U+200B) joined name leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8204) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3: a ZWNJ (U+200C) joined name -> ' || 'Quinn T.'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3: a ZWNJ (U+200C) joined name leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8205) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3: a ZWJ (U+200D) joined name -> ' || 'Quinn T.'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3: a ZWJ (U+200D) joined name leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8288) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3: a word-joiner (U+2060) joined name -> ' || 'Quinn T.'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3: a word-joiner (U+2060) joined name leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(65279) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3: a BOM/ZWNBSP (U+FEFF) joined name -> ' || 'Quinn T.'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3: a BOM/ZWNBSP (U+FEFF) joined name leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn',
  'H3: a single name is kept as-is -> ' || 'Quinn'
);
reset role;
update public.patient_accounts set name = 'quinn'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn',
  'H3: a single lower-case name gets its first letter upper-cased (as the app does) -> ' || 'Quinn'
);
reset role;
update public.patient_accounts set name = 'Quinn ' || chr(129412) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3: an emoji-led surname takes its initial from the first letter -> ' || 'Quinn T.'
);
select ok(
  position(chr(65533) in (select name from public.patient_leaderboard_top10() where league_xp = 80)) = 0,
  'H3: an emoji-led surname has no replacement character'
);
reset role;
update public.patient_accounts set name = chr(129412) || 'Quinn Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3: an emoji-leading name starts at its first letter -> ' || 'Quinn T.'
);
select ok(
  position(chr(65533) in (select name from public.patient_leaderboard_top10() where league_xp = 80)) = 0,
  'H3: an emoji-leading name has no replacement character'
);
reset role;
update public.patient_accounts set name = ''
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3: an empty name falls back to Anonymous -> ' || 'Anonymous'
);
reset role;
update public.patient_accounts set name = '   '
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3: a blank name falls back to Anonymous -> ' || 'Anonymous'
);
reset role;
update public.patient_accounts set name = chr(8203) || chr(8203)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3: a zero-width-only name falls back to Anonymous -> ' || 'Anonymous'
);
reset role;
update public.patient_accounts set name = '@testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3: a value with no local part never shows the handle -> ' || 'Anonymous'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not like '%@%',
  'H3: a value with no local part leaks no @'
);

-- --- H3 r3 (Clara PR #29 r3): every probe shape, plus extra Unicode shapes ---
-- Generated table; [label] matches the probe label in
-- /workspace/qa-pr29/r3/hands-on/leaderboard-rpc-probe-HEAD.txt. Non-ASCII
-- code points are written as chr(n) and shown as <U+XXXX> in the label.
reset role;
update public.patient_accounts set name = 'Testcase, Quinn'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [comma] Testcase, Quinn -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [comma] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [comma] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Testcase,Quinn'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [comma-nospace] Testcase,Quinn -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [comma-nospace] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [comma-nospace] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'quinn.testcase@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r3 [email] quinn.testcase@example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [email] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [email] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'quinn_testcase@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r3 [email-underscore] quinn_testcase@example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [email-underscore] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [email-underscore] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'qtestcase@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r3 [email-plain] qtestcase@example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [email-plain] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [email-plain] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(160) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [nbsp] Quinn<U+00A0>Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [nbsp] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [nbsp] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(9) || chr(10) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [tab-newline] Quinn<U+0009><U+000A>Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [tab-newline] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [tab-newline] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn',
  'H3 r3 [single] Quinn -> Quinn'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [single] no @, no U+FFFD, no invisible/bidi format character'
);
reset role;
update public.patient_accounts set name = 'Quinn Avery Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [three-words] Quinn Avery Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [three-words] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [three-words] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn ' || chr(129412) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [emoji] Quinn <U+1F984>Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [emoji] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [emoji] leaks no surname'
);
reset role;
update public.patient_accounts set name = chr(129412) || ' Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Testcase',
  'H3 r3 [emoji-first] <U+1F984> Testcase -> Testcase'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [emoji-first] no @, no U+FFFD, no invisible/bidi format character'
);
reset role;
update public.patient_accounts set name = 'Zo' || chr(235) || ' ' || chr(197) || 'ngstr' || chr(246) || 'm'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Zo' || chr(235) || ' ' || chr(197) || '.',
  'H3 r3 [unicode] Zo<U+00EB> <U+00C5>ngstr<U+00F6>m -> Zo<U+00EB> <U+00C5>.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [unicode] no @, no U+FFFD, no invisible/bidi format character'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8203) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [zwsp] Quinn<U+200B>Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [zwsp] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [zwsp] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8195) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [emspace] Quinn<U+2003>Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [emspace] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [emspace] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(12288) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [ideographic] Quinn<U+3000>Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [ideographic] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [ideographic] leaks no surname'
);
reset role;
update public.patient_accounts set name = ''
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r3 [empty]  -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [empty] no @, no U+FFFD, no invisible/bidi format character'
);
reset role;
update public.patient_accounts set name = '   '
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r3 [whitespace]     -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [whitespace] no @, no U+FFFD, no invisible/bidi format character'
);
reset role;
update public.patient_accounts set name = chr(160) || chr(160)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r3 [nbsp-only] <U+00A0><U+00A0> -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [nbsp-only] no @, no U+FFFD, no invisible/bidi format character'
);
reset role;
update public.patient_accounts set name = 'Quinn.Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [dot-local] Quinn.Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [dot-local] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [dot-local] leaks no surname'
);
reset role;
update public.patient_accounts set name = '@testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r3 [at-first] @testcase -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [at-first] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [at-first] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinnabellarosalind Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinnabellarosalin',
  'H3 r3 [long] Quinnabellarosalind Testcase -> Quinnabellarosalin'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [long] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [long] leaks no surname'
);
reset role;
update public.patient_accounts set name = null
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r3 [null] NULL -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [null] no @, no U+FFFD, no invisible/bidi format character'
);
reset role;
update public.patient_accounts set name = 'quinn-testcase@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r3 [email-hyphen] quinn-testcase@example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [email-hyphen] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [email-hyphen] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'QUINN.TESTCASE@EXAMPLE.TEST'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r3 [email-upper] QUINN.TESTCASE@EXAMPLE.TEST -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [email-upper] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [email-upper] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'quinn+testcase@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r3 [email-plus] quinn+testcase@example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [email-plus] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [email-plus] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'quinn.t+clinic@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r3 [email-plus-dot] quinn.t+clinic@example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [email-plus-dot] no @, no U+FFFD, no invisible/bidi format character'
);
reset role;
update public.patient_accounts set name = 'quinn.testcase@foo@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r3 [multi-at] quinn.testcase@foo@example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [multi-at] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [multi-at] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'quinn@testcase@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r3 [multi-at2] quinn@testcase@example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [multi-at2] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [multi-at2] leaks no surname'
);
reset role;
update public.patient_accounts set name = '_quinn.testcase_'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [lead-trail-sep] _quinn.testcase_ -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [lead-trail-sep] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [lead-trail-sep] leaks no surname'
);
reset role;
update public.patient_accounts set name = '.testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Testcase',
  'H3 r3 [lead-dot-surname] .testcase -> Testcase'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [lead-dot-surname] no @, no U+FFFD, no invisible/bidi format character'
);
reset role;
update public.patient_accounts set name = 'testcase.'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Testcase',
  'H3 r3 [trail-dot] testcase. -> Testcase'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [trail-dot] no @, no U+FFFD, no invisible/bidi format character'
);
reset role;
update public.patient_accounts set name = '.testcase@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r3 [dot-only-surname-email] .testcase@example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [dot-only-surname-email] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [dot-only-surname-email] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8204) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [zwnj] Quinn<U+200C>Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [zwnj] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [zwnj] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8205) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [zwj] Quinn<U+200D>Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [zwj] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [zwj] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8288) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [wj] Quinn<U+2060>Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [wj] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [wj] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(65279) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [bom] Quinn<U+FEFF>Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [bom] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [bom] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(173) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [soft-hyphen] Quinn<U+00AD>Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [soft-hyphen] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [soft-hyphen] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8206) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [lrm] Quinn<U+200E>Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [lrm] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [lrm] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8207) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [rlm] Quinn<U+200F>Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [rlm] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [rlm] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(6158) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [mongolian-vs] Quinn<U+180E>Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [mongolian-vs] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [mongolian-vs] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8290) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [invisible-times] Quinn<U+2062>Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [invisible-times] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [invisible-times] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8238) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [rlo-joined] Quinn<U+202E>Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [rlo-joined] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [rlo-joined] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn ' || chr(8238) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [rlo-word] Quinn <U+202E>Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [rlo-word] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [rlo-word] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Que' || chr(769) || 'nn Te' || chr(769) || 'stcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Que' || chr(769) || 'nn T.',
  'H3 r3 [combining] Que<U+0301>nn Te<U+0301>stcase -> Que<U+0301>nn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [combining] no @, no U+FFFD, no invisible/bidi format character'
);
reset role;
update public.patient_accounts set name = 'Quinn ' || chr(769) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [combining-lead] Quinn <U+0301>Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [combining-lead] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [combining-lead] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'QQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQ TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'QQQQQQQQQQQQQQQQQQ',
  'H3 r3 [very-long] QQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQ TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT -> QQQQQQQQQQQQQQQQQQ'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [very-long] no @, no U+FFFD, no invisible/bidi format character'
);
reset role;
update public.patient_accounts set name = 'Quinnabellarosalindevangeline.Testcasesmithington'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinnabellarosalin',
  'H3 r3 [very-long-joined] Quinnabellarosalindevangeline.Testcasesmithington -> Quinnabellarosalin'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [very-long-joined] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [very-long-joined] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn2 Testcase99'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn2 T.',
  'H3 r3 [digits] Quinn2 Testcase99 -> Quinn2 T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [digits] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [digits] leaks no surname'
);
reset role;
update public.patient_accounts set name = '12345'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r3 [digits-only] 12345 -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [digits-only] no @, no U+FFFD, no invisible/bidi format character'
);
reset role;
update public.patient_accounts set name = 'Dr. Quinn Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Dr T.',
  'H3 r3 [honorific] Dr. Quinn Testcase -> Dr T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [honorific] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [honorific] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn Testcase-Smith'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn S.',
  'H3 r3 [hyphen-surname] Quinn Testcase-Smith -> Quinn S.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [hyphen-surname] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [hyphen-surname] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Testcase-Smith, Quinn'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn S.',
  'H3 r3 [hyphen-comma] Testcase-Smith, Quinn -> Quinn S.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [hyphen-comma] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [hyphen-comma] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'qtestcase@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r3 [handle-email] qtestcase@example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [handle-email] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [handle-email] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'QuinnTestcase@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r3 [camel-email] QuinnTestcase@example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [camel-email] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [camel-email] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'qtestcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Qtestcase',
  'H3 r3 [plain-handle] qtestcase -> Qtestcase'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [plain-handle] no @, no U+FFFD, no invisible/bidi format character'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(129412) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [emoji-joined] Quinn<U+1F984>Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [emoji-joined] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [emoji-joined] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8201) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [thin-space] Quinn<U+2009>Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [thin-space] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [thin-space] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn' || chr(8232) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [line-sep] Quinn<U+2028>Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [line-sep] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [line-sep] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Testcase, Quinn@example.test'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r3 [comma-email] Testcase, Quinn@example.test -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [comma-email] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [comma-email] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Se' || chr(225) || 'n O''Brien'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Se' || chr(225) || 'n O.',
  'H3 r3 [apostrophe-surname] Se<U+00E1>n O''Brien -> Se<U+00E1>n O.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [apostrophe-surname] no @, no U+FFFD, no invisible/bidi format character'
);
reset role;
update public.patient_accounts set name = 'd''Arcy Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'D''Arcy T.',
  'H3 r3 [apostrophe-lead] d''Arcy Testcase -> D''Arcy T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [apostrophe-lead] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [apostrophe-lead] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn ' || chr(8217) || 'Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [curly-apostrophe-lead] Quinn <U+2019>Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [curly-apostrophe-lead] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [curly-apostrophe-lead] leaks no surname'
);
reset role;
update public.patient_accounts set name = chr(2346) || chr(2381) || chr(2352) || chr(2367) || chr(2351) || chr(2366) || ' ' || chr(2358) || chr(2352) || chr(2381) || chr(2350) || chr(2366)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  chr(2346) || chr(2381) || chr(2352) || chr(2367) || chr(2351) || chr(2366) || ' ' || chr(2358) || '.',
  'H3 r3 [devanagari-conjunct] <U+092A><U+094D><U+0930><U+093F><U+092F><U+093E> <U+0936><U+0930><U+094D><U+092E><U+093E> -> <U+092A><U+094D><U+0930><U+093F><U+092F><U+093E> <U+0936>.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [devanagari-conjunct] no @, no U+FFFD, no invisible/bidi format character'
);
reset role;
update public.patient_accounts set name = 'e' || chr(769) || 'mile Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'E' || chr(769) || 'mile T.',
  'H3 r3 [decomposed-first] e<U+0301>mile Testcase -> E<U+0301>mile T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [decomposed-first] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [decomposed-first] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn ' || chr(1633) || chr(1634)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn',
  'H3 r3 [arabic-digit-token] Quinn <U+0661><U+0662> -> Quinn'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [arabic-digit-token] no @, no U+FFFD, no invisible/bidi format character'
);
reset role;
update public.patient_accounts set name = 'Quinn 2Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [digit-led-surname] Quinn 2Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [digit-led-surname] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [digit-led-surname] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn ' || chr(769) || chr(769)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn',
  'H3 r3 [mark-only-token] Quinn <U+0301><U+0301> -> Quinn'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [mark-only-token] no @, no U+FFFD, no invisible/bidi format character'
);
reset role;
update public.patient_accounts set name = chr(8238) || chr(8238)
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r3 [rlo-only] <U+202E><U+202E> -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [rlo-only] no @, no U+FFFD, no invisible/bidi format character'
);
reset role;
update public.patient_accounts set name = 'quinn testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [lowercase-two] quinn testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [lowercase-two] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [lowercase-two] leaks no surname'
);
reset role;
update public.patient_accounts set name = ','
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r3 [comma-only] , -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [comma-only] no @, no U+FFFD, no invisible/bidi format character'
);
reset role;
update public.patient_accounts set name = 'qtestcase@'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r3 [handle-no-dot] qtestcase@ -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [handle-no-dot] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [handle-no-dot] leaks no surname'
);
reset role;
update public.patient_accounts set name = '@'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Anonymous',
  'H3 r3 [at-only] @ -> Anonymous'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [at-only] no @, no U+FFFD, no invisible/bidi format character'
);
reset role;
update public.patient_accounts set name = 'Quinn+Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3 r3 [plus-joined] Quinn+Testcase -> Quinn T.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [plus-joined] no @, no U+FFFD, no invisible/bidi format character'
);
select ok(
  (select name from public.patient_leaderboard_top10() where league_xp = 80)
    not ilike '%testcase%',
  'H3 r3 [plus-joined] leaks no surname'
);
reset role;
update public.patient_accounts set name = 'Quinn ' || chr(119808) || 'bc'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn ' || chr(119808) || '.',
  'H3 r3 [astral-letter-initial] Quinn <U+1D400>bc -> Quinn <U+1D400>.'
);
select ok(
  (select name !~ ('[@' || chr(65533) || chr(173) || chr(8206) || chr(8207) || chr(6158) || chr(8290) || chr(8238) || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8294) || chr(8295) || chr(8296) || chr(8297) || ']')
     from public.patient_leaderboard_top10() where league_xp = 80),
  'H3 r3 [astral-letter-initial] no @, no U+FFFD, no invisible/bidi format character'
);

-- Clinic scope unchanged: the clinic-B patient never appears here.
select is(
  (select count(*)::int from public.patient_leaderboard_top10()
     where league_xp = 999 or name ilike '%Riley%'),
  0,
  'H3: a clinic-A caller never sees the clinic-B patient'
);

-- --- Caller: clinic-B patient b1001 (own row, other clinic) ----------------
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
