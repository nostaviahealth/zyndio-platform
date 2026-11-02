-- TC-026 review fix (Clara H1, PR #25) + Henry's 2 Nov scope ruling.
--
-- 1. Access: `revoke all ... from public` in 20261101132940 did not remove
--    Supabase's default per-role EXECUTE grant to anon (proacl had anon=X), so
--    anyone holding only the public anon key could call
--    patient_leaderboard_top10() with no session. Revoke from public AND anon
--    explicitly; only signed-in callers (authenticated) keep EXECUTE.
-- 2. Scope: results are limited to the caller's own clinic. The clinic is
--    derived server-side from auth.uid()'s single active patient_record_links
--    row (same source of truth as current_patient_linked()), never from a
--    parameter - the function still takes no arguments. Peers are other
--    patient_accounts rows whose owner has an active link to that same clinic.
--    A caller with no active link (self-signup not yet linked, or staff, who
--    are org_members rather than linked patients) gets an empty list.
-- 3. Display name: first name + last initial ("Jordan R."), never the full
--    name. A single-word name is shown as-is; blank/null stays null.
--
-- The return shape (patient_id, name, avatar_url, league_xp) is unchanged, so
-- create or replace keeps the existing ACL and the Flutter client
-- (gamification_service.fetchStandings) needs no wire change. Grants are
-- re-stated below anyway so this file alone is the source of truth.
--
-- Down path: re-run the function body from 20261101132940 (do NOT restore the
-- anon grant).

create or replace function public.patient_leaderboard_top10()
returns table (patient_id uuid, name text, avatar_url text, league_xp int)
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
  )
  select
    a.patient_id,
    case
      when nullif(btrim(a.name), '') is null then null
      else (
        select case
          when array_length(s.parts, 1) = 1 then s.parts[1]
          else s.parts[1] || ' ' || upper(left(s.parts[array_length(s.parts, 1)], 1)) || '.'
        end
        from (select regexp_split_to_array(btrim(a.name), '\s+') as parts) s
      )
    end as name,
    a.avatar_url,
    a.league_xp
  from public.patient_accounts a
  join public.patient_record_links pl
    on pl.app_user_id = a.patient_id
   and pl.status = 'active'
  join caller_clinic c
    on c.org_id = pl.org_id
  order by a.league_xp desc, a.patient_id
  limit 10;
$$;

comment on function public.patient_leaderboard_top10() is
  'TC-026: top 10 by league_xp among patients actively linked to the CALLER''s '
  'clinic (clinic derived from auth.uid(), no parameters). Name is first name + '
  'last initial. authenticated only - anon and PUBLIC have no EXECUTE (Clara H1).';

revoke all on function public.patient_leaderboard_top10() from public;
revoke all on function public.patient_leaderboard_top10() from anon;
grant execute on function public.patient_leaderboard_top10() to authenticated;
