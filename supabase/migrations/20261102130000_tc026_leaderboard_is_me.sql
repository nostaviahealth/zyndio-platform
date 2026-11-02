-- TC-026 follow-up (Henry, 2 Nov, PR #25): patient_leaderboard_top10() no
-- longer returns patient_id (other patients' auth user ids). It returns a
-- boolean is_me instead - true only for the caller's own row - which is all
-- the Flutter leaderboard needs for the own-row highlight.
--
-- Everything else is unchanged from 20261102110000_tc026_leaderboard_clinic_scope.sql:
-- signed-in only, own clinic only (clinic derived from auth.uid()'s active
-- patient_record_links row, no parameters), first name + last initial.
--
-- A return-type change needs DROP + CREATE (create or replace cannot change
-- the OUT columns). A freshly created function picks up Supabase's default
-- privileges again (EXECUTE to anon/authenticated/service_role), so the
-- grants are re-applied explicitly: revoke from public and anon, grant to
-- authenticated.
--
-- Down path: drop this function and re-run the body + grants from
-- 20261102110000 (never restore the anon grant).

drop function if exists public.patient_leaderboard_top10();

create function public.patient_leaderboard_top10()
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
  )
  select
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
    a.league_xp,
    coalesce(a.patient_id = auth.uid(), false) as is_me
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
  'clinic (clinic derived from auth.uid(), no parameters). Returns name (first '
  'name + last initial), avatar_url, league_xp and is_me (true only for the '
  'caller''s own row) - never patient_id. authenticated only - anon and PUBLIC '
  'have no EXECUTE (Clara H1).';

revoke all on function public.patient_leaderboard_top10() from public;
revoke all on function public.patient_leaderboard_top10() from anon;
grant execute on function public.patient_leaderboard_top10() to authenticated;
