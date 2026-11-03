-- TC-030 item 1 (Clara PR #25 M1): patients must NOT be able to write their own
-- points/badges. 20261102090000_tc026_patient_accounts_premium_lockdown.sql
-- re-granted column-level INSERT/UPDATE to authenticated for every column except
-- the three premium ones - which left xp, coins, league_xp, current_league and
-- league_badges client-writable, so a patient could PATCH league_xp=999999 and
-- rig the clinic leaderboard (Clara confirmed PATCH -> 200). These five columns
-- are gamification state the SERVER awards, never the client.
--
-- Fix: drop the client column grants on those five columns (same column-level
-- technique as the premium lockdown - a plain UPDATE, a multi-column UPDATE, or
-- an upsert's ON CONFLICT DO UPDATE that names any of them now fails with 42501
-- before the write), and add a SECURITY DEFINER award path (award_patient_points)
-- callable only by service_role / the table owner so points can still be awarded
-- server-side. Every other column (name, age, avatar_url, organization, stage,
-- questionnaire_data, fcm_token, created_at, updated_at) stays client-writable,
-- so the Flutter patient flows (profile edit, avatar, questionnaire upsert) are
-- untouched - none of them name a gamification column (verified:
-- patient_provider.dart upserts only patient_id/name/age/avatar_url/organization/
-- questionnaire_data/updated_at). Columns omitted from an INSERT fall back to
-- their defaults with no privilege check, so a patient can still create their
-- own row (xp/coins/league_xp default to 0, current_league 'bronze',
-- league_badges '{}').
--
-- Unaffected on purpose (mirrors the premium lockdown):
--   * service_role keeps its Supabase-granted table-level INSERT/UPDATE, so the
--     award RPC (SECURITY DEFINER, owned by the migration role) and any future
--     server writer can still set these columns.
--   * SELECT is untouched - patients still read their own xp/coins/league.
--
-- Down path: re-grant insert/update (xp, coins, league_xp, current_league,
-- league_badges) on public.patient_accounts to authenticated, and
-- `drop function public.award_patient_points(uuid, int, int, int, text, jsonb);`.

-- Remove the client-side column privileges that let a patient set their own
-- gamification state. 20261102090000 granted these at the column level; revoking
-- the same column level leaves every other column's grant intact.
revoke insert (xp, coins, league_xp, current_league, league_badges)
  on public.patient_accounts from authenticated, anon;
revoke update (xp, coins, league_xp, current_league, league_badges)
  on public.patient_accounts from authenticated, anon;

-- Server-side award path. SECURITY DEFINER runs as the owner (which keeps full
-- table privileges), so it can write the now-locked columns; the body refuses
-- any caller that is not service_role, so an authenticated patient cannot call
-- it to award themselves either. xp/coins/league_xp are ADDED to the current
-- values (an award is an increment, never a client-supplied absolute), so the
-- RPC cannot be used to overwrite a balance to an arbitrary number; the caller
-- passes the already-computed league band in p_current_league, and badges merge
-- in. Mirrors the service_role gate in write_audit_log()
-- (20261026130100_tc005_audit_log_hardening.sql).
create or replace function public.award_patient_points(
  p_patient_id uuid,
  p_xp int default 0,
  p_coins int default 0,
  p_league_xp int default 0,
  p_current_league text default null,
  p_league_badges jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  -- Trusted server-side callers only (the gamification edge/RPC path running as
  -- service_role). Every other caller - an authenticated patient included - is
  -- refused, so this cannot become a self-award backdoor.
  if auth.role() <> 'service_role' then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  update public.patient_accounts
     set xp = xp + greatest(p_xp, 0),
         coins = coins + greatest(p_coins, 0),
         league_xp = league_xp + greatest(p_league_xp, 0),
         current_league = coalesce(p_current_league, current_league),
         league_badges = league_badges || coalesce(p_league_badges, '{}'::jsonb),
         updated_at = now()
   where patient_id = p_patient_id;
end;
$$;

revoke all on function public.award_patient_points(uuid, int, int, int, text, jsonb)
  from public, anon;
grant execute on function public.award_patient_points(uuid, int, int, int, text, jsonb)
  to service_role;

comment on function public.award_patient_points(uuid, int, int, int, text, jsonb) is
  'TC-030 item 1: server-side award path for patient_accounts gamification '
  'columns (xp/coins/league_xp/current_league/league_badges), which patients can '
  'no longer write directly. service_role only - refuses any other caller.';
