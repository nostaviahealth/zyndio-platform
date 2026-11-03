-- TC-030 item 9 server-side enforcement (Clara PR #29 H3). Item 9 was fixed in
-- the Flutter client only: GamificationService.standingFromRow() dropped other
-- patients' avatar_url and formatLeaderboardName() reduced odd names to
-- "First L.". But any signed-in patient calling patient_leaderboard_top10()
-- directly still got, for OTHER patients in their clinic: the avatar_url (photo),
-- the full email when the name was email-like, the full surname for a
-- "Last, First" name, and the full name when it was separated by an NBSP
-- (hands-on/leaderboard-rpc-probe.txt). This moves that cleanup into the RPC.
--
-- This redefinition carries the latest definition verbatim from
-- 20261102130000_tc026_leaderboard_is_me.sql (same signature, return shape,
-- SECURITY DEFINER, pinned search_path, signed-in + own-clinic-only scope, no
-- patient_id) and only:
--   * nulls avatar_url for every row that is not the caller (is_me = false);
--   * replaces the whitespace-only name split with the same robust formatting
--     the Flutter client's leaderboard_name_format logic uses, applied to all
--     rows, so an email-like / "Last, First" / NBSP-joined name can no longer
--     leak a surname, a domain or a full name:
--       - trims leading/trailing whitespace (incl. tab/newline/NBSP);
--       - an email-like value keeps only its local part (domain stripped);
--       - "Last, First" (comma form) is reordered to First then Last;
--       - the name is split on ANY run of whitespace (incl. NBSP) and rendered
--         as first name + upper-cased last initial ("First L."); a single word
--         is used as-is; the result is capped at 18 characters;
--       - a blank/garbage name falls back to 'Anonymous'.
-- The caller's own row keeps its avatar_url. 735 (leaderboard scope) still holds.
--
-- A plain CREATE OR REPLACE suffices here: the signature and OUT columns are
-- unchanged. Grants are left as-is (authenticated only; anon/PUBLIC have none).
--
-- Down path: re-run the body from 20261102130000_tc026_leaderboard_is_me.sql.

create or replace function public.patient_leaderboard_top10()
returns table (name text, avatar_url text, league_xp int, is_me boolean)
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  with caller_clinic as (
    select l.org_id
    from public.patient_record_links l
    where l.app_user_id = auth.uid()
      and l.status = 'active'
  ),
  ranked as (
    select
      a.name as raw_name,
      a.avatar_url,
      a.league_xp,
      a.patient_id,
      coalesce(a.patient_id = auth.uid(), false) as is_me
    from public.patient_accounts a
    join public.patient_record_links pl
      on pl.app_user_id = a.patient_id
     and pl.status = 'active'
    join caller_clinic c
      on c.org_id = pl.org_id
    order by a.league_xp desc, a.patient_id
    limit 10
  )
  select
    fmt.name,
    case when r.is_me then r.avatar_url else null end as avatar_url,
    r.league_xp,
    r.is_me
  from ranked r
  -- Whitespace class incl. NBSP (chr(160)); [[:space:]] alone omits NBSP.
  cross join lateral (select ('[[:space:]' || chr(160) || ']') as ws) w
  -- trim(raw)
  cross join lateral (
    select regexp_replace(
             coalesce(r.raw_name, ''),
             '^' || w.ws || '+|' || w.ws || '+$', '', 'g'
           ) as value
  ) tv
  -- email-like: keep the local part only (domain stripped)
  cross join lateral (
    select case
             when position('@' in tv.value) > 1
               then substr(tv.value, 1, position('@' in tv.value) - 1)
             else tv.value
           end as we
  ) te
  -- "Last, First" -> "First Last" (subsequent split drops any empty piece)
  cross join lateral (
    select case
             when position(',' in te.we) > 0 then
               regexp_replace(substr(te.we, position(',' in te.we) + 1),
                              '^' || w.ws || '+|' || w.ws || '+$', '', 'g')
               || ' ' ||
               regexp_replace(substr(te.we, 1, position(',' in te.we) - 1),
                              '^' || w.ws || '+|' || w.ws || '+$', '', 'g')
             else te.we
           end as working
  ) tw
  -- split on any run of whitespace, dropping empty parts
  cross join lateral (
    select array(
             select p
             from unnest(regexp_split_to_array(tw.working, w.ws || '+')) as p
             where p <> ''
           ) as parts
  ) tp
  cross join lateral (
    select case
             when tv.value = '' then 'Anonymous'
             when array_length(tp.parts, 1) is null then 'Anonymous'
             when array_length(tp.parts, 1) = 1 then left(tp.parts[1], 18)
             else left(
                    tp.parts[1] || ' '
                    || upper(left(tp.parts[array_length(tp.parts, 1)], 1)) || '.',
                    18)
           end as name
  ) fmt
  order by r.league_xp desc, r.patient_id;
$$;

comment on function public.patient_leaderboard_top10() is
  'TC-026/TC-030: top 10 by league_xp among patients actively linked to the '
  'CALLER''s clinic (clinic derived from auth.uid(), no parameters). Returns '
  'name (first name + last initial, robustly formatted so an email-like / '
  '"Last, First" / NBSP-joined name leaks no surname, domain or full name), '
  'league_xp and is_me (true only for the caller''s own row) - never '
  'patient_id. avatar_url is returned only for the caller''s own row; every '
  'other row''s avatar_url is NULL (Clara H3: no profile photos of other '
  'patients). authenticated only - anon and PUBLIC have no EXECUTE.';
