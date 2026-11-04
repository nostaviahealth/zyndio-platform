-- APP-01: patients sign in from a Zyndio enrolment invite with an emailed
-- one-time code; open self-sign-up is off unless an org turns it on.
--
-- Three pieces, all service-role only (the patient-* Edge Functions are the
-- only callers):
--   1. organizations.patient_self_signup_enabled - the org setting that
--      patient-signup now checks (default false = invite only).
--   2. patient_invites + issue_patient_invite() - the one invite path, used
--      by create-patient today and by the integration API (POST /v1/patients)
--      later. The invite itself carries no credential: it tells the patient
--      to open the app and sign in with their email.
--   3. patient_login_codes + issue/redeem_patient_login_code() - 6-digit,
--      10-minute, single-use codes with a 5-wrong-tries / 15-minute lock.
--
-- Why our own codes instead of GoTrue's email OTP: a GoTrue OTP can be
-- verified by anyone straight against /auth/v1/verify, with no per-account
-- attempt limit, so a 6-digit code would be guessable. Our code never
-- reaches GoTrue. Once it is redeemed here, patient-verify-login-code mints
-- the session server-side from a one-off admin magic-link token_hash that
-- never leaves the Edge Function.
--
-- Enumeration safety (same rule as patient-signup / PSU-ENUM-01): every
-- well-formed email gets a code row, eligible or not. An ineligible email's
-- code is random and never sent, so it can't be redeemed, but it expires
-- and locks out exactly like a real one. Unknown and known emails therefore
-- look the same through request, verify, expiry and lockout.

-- ---------------------------------------------------------------------------
-- 1. org setting
-- ---------------------------------------------------------------------------

alter table public.organizations
  add column if not exists patient_self_signup_enabled boolean not null default false;

comment on column public.organizations.patient_self_signup_enabled is
  'APP-01: when false (default) patients can only join from a care-team invite; '
  'patient-signup refuses with signup_disabled.';

create or replace function public.patient_self_signup_open(p_org_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select coalesce(
    (select o.patient_self_signup_enabled from public.organizations o where o.id = p_org_id),
    false
  );
$$;

revoke all on function public.patient_self_signup_open(uuid) from public, anon, authenticated;
grant execute on function public.patient_self_signup_open(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- Who may sign in with a patient code: an account with a patients row (staff
-- created or record-linked) or a self-signup marker - never staff and never
-- a platform admin (their sign-in needs a password and aal2), never a banned
-- account.
-- ---------------------------------------------------------------------------

create or replace function public._patient_code_signin_eligible(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select p_user_id is not null
    and exists (
      select 1 from auth.users u
      where u.id = p_user_id
        and (u.banned_until is null or u.banned_until < now())
    )
    and (
      exists (select 1 from public.patients p where p.id = p_user_id)
      or public.is_patient_self_signup(p_user_id)
    )
    and not exists (select 1 from public.org_members m where m.user_id = p_user_id)
    and not exists (select 1 from public.platform_admins a where a.user_id = p_user_id);
$$;

revoke all on function public._patient_code_signin_eligible(uuid) from public, anon, authenticated;
grant execute on function public._patient_code_signin_eligible(uuid) to service_role;

create or replace function public._patient_email_hash(p_email text)
returns text
language sql
immutable
set search_path = pg_catalog, public
as $$
  select encode(extensions.digest(lower(btrim(p_email)), 'sha256'), 'hex');
$$;

revoke all on function public._patient_email_hash(text) from public, anon, authenticated;
grant execute on function public._patient_email_hash(text) to service_role;

-- ---------------------------------------------------------------------------
-- 2. invites
-- ---------------------------------------------------------------------------

create table public.patient_invites (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  patient_id uuid not null references public.patients (id) on delete cascade,
  email text not null check (char_length(email) <= 254),
  invited_by uuid references auth.users (id) on delete set null,
  source text not null check (source in ('staff', 'api')),
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  revoked_at timestamptz
);

create index patient_invites_org_id_idx on public.patient_invites (org_id);
create index patient_invites_patient_id_idx on public.patient_invites (patient_id);

-- At most one open invite per patient; re-sending revokes the previous one.
create unique index patient_invites_one_open_per_patient
  on public.patient_invites (patient_id)
  where accepted_at is null and revoked_at is null;

alter table public.patient_invites enable row level security;
alter table public.patient_invites force row level security;
revoke all on public.patient_invites from anon, authenticated;
grant select on public.patient_invites to authenticated;

-- Clinic staff can see their own clinic's invite status (e.g. "invited" vs
-- "joined" on the roster). Nobody writes through the API: only
-- issue_patient_invite() and redeem_patient_login_code() do.
create policy patient_invites_staff_select on public.patient_invites
  for select to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('org_admin', 'physician', 'care_coordinator')
  );

create or replace function public.issue_patient_invite(
  p_patient_id uuid,
  p_invited_by uuid default null,
  p_source text default 'staff'
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org_id uuid;
  v_email text;
  v_invite_id uuid;
begin
  if p_source not in ('staff', 'api') then
    raise exception 'invalid invite source' using errcode = '22023';
  end if;

  select p.org_id into v_org_id from public.patients p where p.id = p_patient_id;
  if v_org_id is null then
    raise exception 'patient not found' using errcode = 'P0002';
  end if;

  if not public._patient_code_signin_eligible(p_patient_id) then
    raise exception 'account cannot receive a patient invite' using errcode = '42501';
  end if;

  select lower(u.email) into v_email from auth.users u where u.id = p_patient_id;
  if v_email is null then
    raise exception 'patient has no email' using errcode = 'P0002';
  end if;

  update public.patient_invites
    set revoked_at = now()
    where patient_id = p_patient_id
      and accepted_at is null
      and revoked_at is null;

  insert into public.patient_invites (org_id, patient_id, email, invited_by, source)
    values (v_org_id, p_patient_id, v_email, p_invited_by, p_source)
    returning id into v_invite_id;

  perform public._audit_log_insert(
    'patient_invite_issued', p_invited_by, p_patient_id, v_org_id,
    jsonb_build_object('invite_id', v_invite_id, 'source', p_source)
  );

  return jsonb_build_object('invite_id', v_invite_id, 'org_id', v_org_id, 'email', v_email);
end;
$$;

revoke all on function public.issue_patient_invite(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.issue_patient_invite(uuid, uuid, text) to service_role;

-- ---------------------------------------------------------------------------
-- 3. sign-in codes
-- ---------------------------------------------------------------------------

create table public.patient_login_codes (
  email_hash text primary key,
  user_id uuid references auth.users (id) on delete cascade,
  code_hash text not null,
  expires_at timestamptz not null,
  attempts int not null default 0,
  used_at timestamptz,
  locked_until timestamptz,
  created_at timestamptz not null default now()
);

create index patient_login_codes_user_id_idx on public.patient_login_codes (user_id);

alter table public.patient_login_codes enable row level security;
alter table public.patient_login_codes force row level security;
revoke all on public.patient_login_codes from anon, authenticated;

-- Issues a fresh code for p_email and returns the user id to send it to, or
-- null when the email is not an eligible patient (the caller then sends
-- nothing but answers the same). A live lock survives a re-issue, so asking
-- for a new code can't reset the 5-try limit.
create or replace function public.issue_patient_login_code(
  p_email text,
  p_code text,
  p_ttl_seconds int default 600
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid;
  v_hash text;
begin
  if p_code !~ '^[0-9]{6}$' then
    raise exception 'code must be 6 digits' using errcode = '22023';
  end if;

  v_hash := public._patient_email_hash(p_email);

  select u.id into v_user_id
    from auth.users u
    where lower(u.email) = lower(btrim(p_email))
    limit 1;

  if not public._patient_code_signin_eligible(v_user_id) then
    v_user_id := null;
  end if;

  insert into public.patient_login_codes (email_hash, user_id, code_hash, expires_at)
    values (
      v_hash,
      v_user_id,
      extensions.crypt(p_code, extensions.gen_salt('bf', 8)),
      now() + make_interval(secs => p_ttl_seconds)
    )
  on conflict (email_hash) do update
    set user_id = excluded.user_id,
        code_hash = excluded.code_hash,
        expires_at = excluded.expires_at,
        attempts = 0,
        used_at = null,
        locked_until = case
          when public.patient_login_codes.locked_until > now()
          then public.patient_login_codes.locked_until
          else null
        end,
        created_at = now();

  return v_user_id;
end;
$$;

revoke all on function public.issue_patient_login_code(text, text, int) from public, anon, authenticated;
grant execute on function public.issue_patient_login_code(text, text, int) to service_role;

-- One atomic check. Returns {result, user_id, retry_after_seconds} where
-- result is ok | invalid | expired | locked. The 5th wrong try burns the
-- code and locks the email for p_lock_seconds. On ok the code is spent and
-- any open invite for the patient is marked accepted.
create or replace function public.redeem_patient_login_code(
  p_email text,
  p_code text,
  p_max_attempts int default 5,
  p_lock_seconds int default 900
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_row public.patient_login_codes%rowtype;
  v_org_id uuid;
begin
  select * into v_row
    from public.patient_login_codes c
    where c.email_hash = public._patient_email_hash(p_email)
    for update;

  if not found then
    return jsonb_build_object('result', 'invalid');
  end if;

  if v_row.locked_until is not null and v_row.locked_until > now() then
    return jsonb_build_object(
      'result', 'locked',
      'retry_after_seconds', ceil(extract(epoch from v_row.locked_until - now()))::int
    );
  end if;

  if v_row.used_at is not null or v_row.expires_at <= now() then
    return jsonb_build_object('result', 'expired');
  end if;

  if p_code ~ '^[0-9]{6}$'
     and extensions.crypt(p_code, v_row.code_hash) = v_row.code_hash
     and v_row.user_id is not null
     and public._patient_code_signin_eligible(v_row.user_id) then
    update public.patient_login_codes
      set used_at = now(), attempts = 0, locked_until = null
      where email_hash = v_row.email_hash;

    update public.patient_invites
      set accepted_at = now()
      where patient_id = v_row.user_id
        and accepted_at is null
        and revoked_at is null
      returning org_id into v_org_id;

    if v_org_id is not null then
      perform public._audit_log_insert(
        'patient_invite_accepted', v_row.user_id, v_row.user_id, v_org_id, '{}'::jsonb
      );
    end if;

    return jsonb_build_object('result', 'ok', 'user_id', v_row.user_id);
  end if;

  if v_row.attempts + 1 >= p_max_attempts then
    update public.patient_login_codes
      set attempts = v_row.attempts + 1,
          used_at = now(),
          locked_until = now() + make_interval(secs => p_lock_seconds)
      where email_hash = v_row.email_hash;
    return jsonb_build_object('result', 'locked', 'retry_after_seconds', p_lock_seconds);
  end if;

  update public.patient_login_codes
    set attempts = v_row.attempts + 1
    where email_hash = v_row.email_hash;
  return jsonb_build_object('result', 'invalid');
end;
$$;

revoke all on function public.redeem_patient_login_code(text, text, int, int) from public, anon, authenticated;
grant execute on function public.redeem_patient_login_code(text, text, int, int) to service_role;

-- ---------------------------------------------------------------------------
-- 4. The emailed code rides notification_outbox under payload.token, so the
--    TC-018 scrub (on send, or after 15 minutes) clears it like the other
--    token-bearing types.
-- ---------------------------------------------------------------------------

create or replace function public._notification_outbox_scrub_payload(p_type text, p_payload jsonb)
returns jsonb
language sql
immutable
set search_path = pg_catalog, public
as $$
  select case
    when p_type = any (array['invite', 'verify_email', 'password_reset', 'patient_login_code'])
         and p_payload ? 'token'
    then p_payload || jsonb_build_object('token', null)
    else p_payload
  end;
$$;

create or replace function public._scrub_stale_notification_outbox()
returns int
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_count int;
begin
  with scrubbed as (
    update public.notification_outbox
      set payload = public._notification_outbox_scrub_payload(type, payload),
          scrubbed_at = now()
      where scrubbed_at is null
        and type = any (array['invite', 'verify_email', 'password_reset', 'patient_login_code'])
        and payload ? 'token'
        and (status <> 'pending' or created_at < now() - interval '15 minutes')
      returning 1
  )
  select count(*) into v_count from scrubbed;

  return v_count;
end;
$$;
