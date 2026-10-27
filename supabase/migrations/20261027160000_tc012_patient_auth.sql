-- TC-012 slice 1: patient self-signup / verify / login / reset / delete.
-- No record matching in this migration (docs/RECORD_MATCHING.md is design-only
-- until Clara checks it) - patients created via this flow get no org_id and
-- no public.patients row until a future linking slice. That absence is what
-- already keeps every clinical table (patient_profiles/lab_reports/consents,
-- all FK'd to patients.id) unreadable to a self-signup account: there is
-- nothing there to read. The email_confirmed_at gate added below is
-- defense-in-depth on top of that, per PSU-EV-01.

-- ---------------------------------------------------------------------------
-- generic per-bucket/per-key rate limiter (fixed window), used by the patient
-- signup/login/reset/resend Edge Functions for per-IP and per-email-hash
-- throttling. auth_attempt_state (TC-005) already covers per-*account*
-- lockout for login via the password_verification_attempt hook - this table
-- is for the IP and pre-account-resolution dimensions that hook can't see.
-- ---------------------------------------------------------------------------

create table public.rate_limit_counters (
  bucket text not null,
  key_hash text not null,
  window_start timestamptz not null default now(),
  count int not null default 0,
  primary key (bucket, key_hash)
);

alter table public.rate_limit_counters enable row level security;
alter table public.rate_limit_counters force row level security;
revoke all on public.rate_limit_counters from anon, authenticated;

-- Atomic (single upsert statement): returns true if this call is within
-- p_limit for the current p_window_seconds window, false if it should be
-- rejected. A fresh/expired window resets the count to 1 in the same
-- statement, so there is no separate read-then-write race.
create or replace function public.check_and_consume_rate_limit(
  p_bucket text,
  p_key_hash text,
  p_limit int,
  p_window_seconds int
)
returns boolean
language sql
security definer
set search_path = pg_catalog, public
as $$
  insert into public.rate_limit_counters (bucket, key_hash, window_start, count)
  values (p_bucket, p_key_hash, now(), 1)
  on conflict (bucket, key_hash) do update
    set count = case
          when public.rate_limit_counters.window_start < now() - make_interval(secs => p_window_seconds)
          then 1
          else public.rate_limit_counters.count + 1
        end,
        window_start = case
          when public.rate_limit_counters.window_start < now() - make_interval(secs => p_window_seconds)
          then now()
          else public.rate_limit_counters.window_start
        end
  returning count <= p_limit;
$$;

revoke all on function public.check_and_consume_rate_limit(text, text, int, int) from public, anon, authenticated;
grant execute on function public.check_and_consume_rate_limit(text, text, int, int) to service_role;

-- ---------------------------------------------------------------------------
-- email verification (24h TTL, Henry 27 Oct) - our own token, not GoTrue's
-- built-in confirmation mailer, so sign-up/verify/resend stay fully
-- enumeration-safe and don't depend on SMTP/inbucket wiring this card
-- doesn't configure. Service-role only: Edge Functions issue/redeem these.
-- ---------------------------------------------------------------------------

create table public.patient_email_verifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null default (now() + interval '24 hours'),
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create index patient_email_verifications_user_id_idx on public.patient_email_verifications (user_id);

alter table public.patient_email_verifications enable row level security;
alter table public.patient_email_verifications force row level security;
revoke all on public.patient_email_verifications from anon, authenticated;

-- Single atomic UPDATE: a second redemption of the same token (PSU-EV-03)
-- or an expired one (PSU-EV-02) both find zero matching rows and return
-- null, with no separate check-then-write window for a replay to land in.
create or replace function public.redeem_patient_email_verification(p_token_hash text)
returns uuid
language sql
security definer
set search_path = pg_catalog, public
as $$
  update public.patient_email_verifications
    set used_at = now()
    where token_hash = p_token_hash
      and used_at is null
      and expires_at > now()
    returning user_id;
$$;

revoke all on function public.redeem_patient_email_verification(text) from public, anon, authenticated;
grant execute on function public.redeem_patient_email_verification(text) to service_role;

-- ---------------------------------------------------------------------------
-- password reset (1h TTL, Henry 27 Oct) - same shape as verification, kept
-- as a separate table/function pair so the two TTLs and audit trails never
-- collide, and so a verification link can never be replayed as a reset link.
-- ---------------------------------------------------------------------------

create table public.patient_password_resets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null default (now() + interval '1 hour'),
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create index patient_password_resets_user_id_idx on public.patient_password_resets (user_id);

alter table public.patient_password_resets enable row level security;
alter table public.patient_password_resets force row level security;
revoke all on public.patient_password_resets from anon, authenticated;

create or replace function public.redeem_patient_password_reset(p_token_hash text)
returns uuid
language sql
security definer
set search_path = pg_catalog, public
as $$
  update public.patient_password_resets
    set used_at = now()
    where token_hash = p_token_hash
      and used_at is null
      and expires_at > now()
    returning user_id;
$$;

revoke all on function public.redeem_patient_password_reset(text) from public, anon, authenticated;
grant execute on function public.redeem_patient_password_reset(text) to service_role;

-- ---------------------------------------------------------------------------
-- PSU-EV-01 defense-in-depth: gate every patient-self clinical-table read on
-- email_confirmed_at, not just on a patients row existing. Drop + recreate
-- rather than ALTER POLICY (Postgres has no "add condition" form).
-- ---------------------------------------------------------------------------

create or replace function public.current_email_confirmed()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select coalesce(
    (select email_confirmed_at is not null from auth.users where id = auth.uid()),
    false
  );
$$;

drop policy if exists patients_self_select on public.patients;
create policy patients_self_select on public.patients
  for select
  to authenticated
  using (id = auth.uid() and public.current_email_confirmed());

drop policy if exists patients_self_update on public.patients;
create policy patients_self_update on public.patients
  for update
  to authenticated
  using (id = auth.uid() and public.current_email_confirmed())
  with check (id = auth.uid());

drop policy if exists patient_profiles_self_select on public.patient_profiles;
create policy patient_profiles_self_select on public.patient_profiles
  for select
  to authenticated
  using (patient_id = auth.uid() and public.current_email_confirmed());

-- M1 (review_group_a) pinned org_id on every patient-self write via a WITH
-- CHECK subquery against patients.org_id - that condition must survive this
-- drop + recreate verbatim, or a patient could move their own clinical rows
-- cross-org again. Only the USING clause gains the email_confirmed_at gate.
drop policy if exists patient_profiles_self_update on public.patient_profiles;
create policy patient_profiles_self_update on public.patient_profiles
  for update
  to authenticated
  using (patient_id = auth.uid() and public.current_email_confirmed())
  with check (
    patient_id = auth.uid()
    and org_id = (select org_id from public.patients where id = auth.uid())
  );

drop policy if exists lab_reports_self_select on public.lab_reports;
create policy lab_reports_self_select on public.lab_reports
  for select
  to authenticated
  using (patient_id = auth.uid() and public.current_email_confirmed());

drop policy if exists lab_reports_self_insert on public.lab_reports;
create policy lab_reports_self_insert on public.lab_reports
  for insert
  to authenticated
  with check (
    patient_id = auth.uid()
    and public.current_email_confirmed()
    and org_id = (select org_id from public.patients where id = auth.uid())
  );

drop policy if exists consents_self_select on public.consents;
create policy consents_self_select on public.consents
  for select
  to authenticated
  using (patient_id = auth.uid() and public.current_email_confirmed());

drop policy if exists consents_self_insert on public.consents;
create policy consents_self_insert on public.consents
  for insert
  to authenticated
  with check (
    patient_id = auth.uid()
    and public.current_email_confirmed()
    and org_id = (select org_id from public.patients where id = auth.uid())
  );

drop policy if exists consents_self_update on public.consents;
create policy consents_self_update on public.consents
  for update
  to authenticated
  using (patient_id = auth.uid() and public.current_email_confirmed())
  with check (
    patient_id = auth.uid()
    and org_id = (select org_id from public.patients where id = auth.uid())
  );

-- ---------------------------------------------------------------------------
-- account deletion (Apple 5.1.1(v)): service-role-only RPC that does the
-- app-side anonymise/delete step. auth.users row itself and session
-- revocation are handled by the Edge Function via the GoTrue admin API
-- (not reachable from plain SQL) - this RPC just clears what SQL owns:
-- any patients row (cascades to patient_profiles/lab_reports/consents via
-- existing FKs) and any outstanding verification/reset tokens.
-- ---------------------------------------------------------------------------

create or replace function public.delete_patient_app_data(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  delete from public.patients where id = p_user_id;
  delete from public.patient_email_verifications where user_id = p_user_id;
  delete from public.patient_password_resets where user_id = p_user_id;
end;
$$;

revoke all on function public.delete_patient_app_data(uuid) from public, anon, authenticated;
grant execute on function public.delete_patient_app_data(uuid) to service_role;
