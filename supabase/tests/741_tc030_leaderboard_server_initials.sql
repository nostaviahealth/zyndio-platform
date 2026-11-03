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

-- Email-like name -> "First L." from the local part; no @, no domain and no
-- surname (Clara PR #29 r2: the local part "quinn.testcase" leaked the surname).
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  'Quinn T.',
  'H3: an email-like name is reduced to first name + last initial'
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
  'Quinn T.',
  'H3: an underscore email local part -> ' || 'Quinn T.'
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
  'Quinn T.',
  'H3: a hyphen email local part -> ' || 'Quinn T.'
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
  'Quinn ' || chr(129412) || '.',
  'H3: an emoji-led surname keeps the whole emoji as the initial -> ' || 'Quinn ' || chr(129412) || '.'
);
select ok(
  position(chr(65533) in (select name from public.patient_leaderboard_top10() where league_xp = 80)) = 0,
  'H3: an emoji-led surname keeps the whole emoji as the initial has no replacement character'
);
reset role;
update public.patient_accounts set name = chr(129412) || 'Quinn Testcase'
 where patient_id = '00000000-0000-0000-0000-0000000a6102';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select name from public.patient_leaderboard_top10() where league_xp = 80),
  chr(129412) || 'Quinn T.',
  'H3: an emoji-leading name keeps the whole emoji -> ' || chr(129412) || 'Quinn T.'
);
select ok(
  position(chr(65533) in (select name from public.patient_leaderboard_top10() where league_xp = 80)) = 0,
  'H3: an emoji-leading name keeps the whole emoji has no replacement character'
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
  $$ values ('Riley C.'::text, true, true) $$,
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
