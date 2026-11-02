-- TC-026: replacement for the removed `profiles` table for the Flutter patient
-- app's own account/engagement data (gamification, avatar, questionnaire,
-- FCM token, subscription status). Deliberately NOT `patients`/`patient_profiles`:
-- those require org_id (not null) and are only reachable once a patient is
-- staff-provisioned or record-linked (current_patient_linked()) - self-signup
-- patients (TC-012) have neither until they link to a clinic, so premium/xp/
-- avatar could never be stored for them there. This table is keyed directly off
-- auth.users and carries no clinical data, so it needs no org scoping and no
-- staff access at all.
--
-- is_premium/subscription_plan/subscription_expires_at are the one part of this
-- row a patient must never set themselves (TC-026 card item 2): normal RLS
-- self-update covers every other column, and a column-level REVOKE blocks
-- those three specifically, even via upsert. Only the service-role RevenueCat
-- webhook (supabase/functions/handle-revenuecat-webhook) writes them.
--
-- Down path (if TC-026 is ever reverted): `drop function
-- public.patient_leaderboard_top10(); drop table public.patient_accounts;` -
-- nothing else references either object.

create table public.patient_accounts (
  patient_id uuid primary key references auth.users (id) on delete cascade,
  name text,
  age int,
  avatar_url text,
  organization text,
  stage text not null default 'profile_creation',
  questionnaire_data jsonb not null default '{}'::jsonb,
  fcm_token text,
  xp int not null default 0,
  coins int not null default 0,
  league_xp int not null default 0,
  current_league text not null default 'bronze',
  league_reset_at timestamptz not null default now(),
  league_badges jsonb not null default '{}'::jsonb,
  is_premium boolean not null default false,
  subscription_plan text not null default 'free',
  subscription_expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.patient_accounts enable row level security;
alter table public.patient_accounts force row level security;

create policy patient_accounts_self_select on public.patient_accounts
  for select
  to authenticated
  using (patient_id = auth.uid());

create policy patient_accounts_self_insert on public.patient_accounts
  for insert
  to authenticated
  with check (patient_id = auth.uid());

create policy patient_accounts_self_update on public.patient_accounts
  for update
  to authenticated
  using (patient_id = auth.uid())
  with check (patient_id = auth.uid());

-- Column-level lockdown: even though the row-level policy above allows the
-- owner to UPDATE their own row, Postgres also checks column privileges for
-- every column named in an UPDATE's SET list (upsert's ON CONFLICT DO UPDATE
-- included). Revoking UPDATE on just these three columns means any client
-- write that touches them - direct update, upsert, whatever - fails with a
-- permission error naming the column, before RLS is even evaluated.
revoke update (is_premium, subscription_plan, subscription_expires_at)
  on public.patient_accounts from authenticated, anon;

-- Public leaderboard: gamification_service.fetchStandings() needs name/
-- avatar_url/league_xp across *other* patients, which the self-only RLS above
-- would otherwise block entirely. A narrow security-definer RPC (same pattern
-- as current_org_id()/current_role() in 20261026120000_tc005_schema.sql)
-- exposes only these four non-sensitive columns - never is_premium or
-- anything else.
create function public.patient_leaderboard_top10()
returns table (patient_id uuid, name text, avatar_url text, league_xp int)
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select patient_id, name, avatar_url, league_xp
  from public.patient_accounts
  order by league_xp desc
  limit 10;
$$;

revoke all on function public.patient_leaderboard_top10() from public;
grant execute on function public.patient_leaderboard_top10() to authenticated;
