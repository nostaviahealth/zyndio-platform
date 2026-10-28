-- TC-012 record matching: tables + bind/redeem/unlink RPCs (Clara APPROVED RECORD_MATCHING).
-- Pepper for code MACs: GUC app.link_code_pepper (Edge/Vault sets it; tests set a fixed value).

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.patient_record_links (
  id uuid primary key default gen_random_uuid(),
  app_user_id uuid not null references auth.users (id) on delete cascade,
  org_id uuid not null references public.organizations (id),
  telehealth_patient_id text not null,
  status text not null check (status in ('active', 'revoked', 'pending_review')),
  linked_at timestamptz,
  revoked_at timestamptz,
  proof_method text not null check (proof_method in ('telehealth_otp', 'clinic_code')),
  created_at timestamptz not null default now()
);

create unique index patient_record_links_one_active_app
  on public.patient_record_links (app_user_id) where status = 'active';
create unique index patient_record_links_one_active_th
  on public.patient_record_links (telehealth_patient_id) where status = 'active';

alter table public.patient_record_links enable row level security;
alter table public.patient_record_links force row level security;
revoke all on public.patient_record_links from anon, authenticated;

create table public.patient_link_codes (
  id uuid primary key default gen_random_uuid(),
  telehealth_patient_id text not null,
  org_id uuid not null references public.organizations (id),
  method text not null check (method in ('telehealth_otp', 'clinic_code')),
  issued_to_app_user_id uuid references auth.users (id) on delete cascade,
  code_mac text not null,
  expires_at timestamptz not null,
  used_at timestamptz,
  killed_at timestamptz,
  wrong_try_count int not null default 0,
  created_at timestamptz not null default now(),
  created_by text,
  superseded_at timestamptz,
  constraint patient_link_codes_otp_bound check (
    method <> 'telehealth_otp' or issued_to_app_user_id is not null
  )
);

create index patient_link_codes_otp_lookup
  on public.patient_link_codes (issued_to_app_user_id, method)
  where method = 'telehealth_otp' and used_at is null and killed_at is null and superseded_at is null;
create index patient_link_codes_mac_lookup
  on public.patient_link_codes (code_mac)
  where method = 'clinic_code' and used_at is null and killed_at is null;

alter table public.patient_link_codes enable row level security;
alter table public.patient_link_codes force row level security;
revoke all on public.patient_link_codes from anon, authenticated;

create table public.patient_link_attempts (
  app_user_id uuid primary key references auth.users (id) on delete cascade,
  wrong_count int not null default 0,
  locked_until timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.patient_link_attempts enable row level security;
alter table public.patient_link_attempts force row level security;
revoke all on public.patient_link_attempts from anon, authenticated;

create table public.patient_link_global_failures (
  window_start timestamptz not null primary key,
  fail_count int not null default 0
);

alter table public.patient_link_global_failures enable row level security;
alter table public.patient_link_global_failures force row level security;
revoke all on public.patient_link_global_failures from anon, authenticated;

create table public.patient_link_review_queue (
  id uuid primary key default gen_random_uuid(),
  app_user_id uuid not null references auth.users (id) on delete cascade,
  org_id uuid not null references public.organizations (id),
  reason text not null,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'open',
  created_at timestamptz not null default now()
);

alter table public.patient_link_review_queue enable row level security;
alter table public.patient_link_review_queue force row level security;
revoke all on public.patient_link_review_queue from anon, authenticated;

-- Clinic-channel notice outbox (FakeTelehealthAdapter / Edge).
create table public.telehealth_message_outbox (
  id uuid primary key default gen_random_uuid(),
  telehealth_patient_id text not null,
  body text not null,
  created_at timestamptz not null default now()
);

alter table public.telehealth_message_outbox enable row level security;
alter table public.telehealth_message_outbox force row level security;
revoke all on public.telehealth_message_outbox from anon, authenticated;

-- Own-row read of active link status for the patient app (opaque ids only).
create policy patient_record_links_self_select on public.patient_record_links
  for select to authenticated
  using (app_user_id = auth.uid());

grant select on public.patient_record_links to authenticated;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- Pepper body replaced by 20261027190000 (Vault-only, fail closed).
-- Placeholder here so earlier migrations still apply on db reset before 190000.
create or replace function public._link_code_pepper()
returns text
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
begin
  raise exception 'link_code_pepper secret is not configured in Vault'
    using errcode = 'P0001';
end;
$$;

create or replace function public.normalise_link_code(p_code text)
returns text
language sql
immutable
as $$
  select upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
$$;

create or replace function public.link_code_mac(p_code text)
returns text
language sql
stable
as $$
  select encode(
    extensions.hmac(public.normalise_link_code(p_code), public._link_code_pepper(), 'sha256'),
    'hex'
  );
$$;

revoke all on function public._link_code_pepper() from public, anon, authenticated;
revoke all on function public.link_code_mac(text) from public, anon, authenticated;
grant execute on function public.normalise_link_code(text) to authenticated, service_role;
grant execute on function public.link_code_mac(text) to service_role;

-- current_patient_linked: active link OR grandfathered clinic-provisioned patients row.
create or replace function public.current_patient_linked()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select
    exists (
      select 1
      from public.patient_record_links l
      where l.app_user_id = auth.uid()
        and l.status = 'active'
    )
    or exists (
      select 1
      from public.patients p
      where p.id = auth.uid()
        and p.org_id is not null
        and not public.is_patient_self_signup(auth.uid())
    );
$$;

comment on function public.current_patient_linked() is
  'Active patient_record_links row, or grandfathered clinic-provisioned patients '
  '(org_id set, not a self-signup marker). Self-signup clinical reads require bind (PSU-TO-15).';

-- ---------------------------------------------------------------------------
-- Lockout helper
-- ---------------------------------------------------------------------------

create or replace function public._patient_link_locked(p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_until timestamptz;
begin
  select locked_until into v_until
  from public.patient_link_attempts
  where app_user_id = p_user_id;
  return v_until is not null and v_until > now();
end;
$$;

create or replace function public._patient_link_register_wrong(p_user_id uuid, p_lock_after int default 5, p_lock_minutes int default 15)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_count int;
begin
  insert into public.patient_link_attempts (app_user_id, wrong_count, updated_at)
  values (p_user_id, 1, now())
  on conflict (app_user_id) do update
    set wrong_count = case
          when public.patient_link_attempts.locked_until is not null
               and public.patient_link_attempts.locked_until > now()
            then public.patient_link_attempts.wrong_count
          when public.patient_link_attempts.locked_until is not null
               and public.patient_link_attempts.locked_until <= now()
            then 1
          else public.patient_link_attempts.wrong_count + 1
        end,
        updated_at = now()
  returning wrong_count into v_count;

  if v_count >= p_lock_after then
    update public.patient_link_attempts
      set locked_until = now() + make_interval(mins => p_lock_minutes),
          updated_at = now()
      where app_user_id = p_user_id;
  end if;
end;
$$;

create or replace function public._patient_link_clear_attempts(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  delete from public.patient_link_attempts where app_user_id = p_user_id;
end;
$$;

-- Global clinic-code breaker (15-min windows, threshold 50).
create or replace function public._clinic_code_breaker_tripped()
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_start timestamptz := date_trunc('hour', now())
    + make_interval(mins => (extract(minute from now())::int / 15) * 15);
  v_count int;
begin
  select fail_count into v_count
  from public.patient_link_global_failures
  where window_start = v_start;
  return coalesce(v_count, 0) >= 50;
end;
$$;

create or replace function public._clinic_code_breaker_bump()
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_start timestamptz := date_trunc('hour', now())
    + make_interval(mins => (extract(minute from now())::int / 15) * 15);
begin
  insert into public.patient_link_global_failures (window_start, fail_count)
  values (v_start, 1)
  on conflict (window_start) do update
    set fail_count = public.patient_link_global_failures.fail_count + 1;
end;
$$;

-- ---------------------------------------------------------------------------
-- Bind / notices (internal)
-- ---------------------------------------------------------------------------

create or replace function public._enqueue_link_notices(
  p_app_user_id uuid,
  p_org_id uuid,
  p_telehealth_patient_id text,
  p_kind text  -- 'linked' | 'unlinked'
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_clinic_body text;
  v_email_type text;
begin
  if p_kind = 'linked' then
    v_clinic_body := 'Your record was linked to a Zyndio app account. Not you? Contact your clinic.';
    v_email_type := 'patient_record_linked';
  else
    v_clinic_body := 'A Zyndio app account was unlinked from your record. Not you? Contact your clinic.';
    v_email_type := 'patient_record_unlinked';
  end if;

  insert into public.telehealth_message_outbox (telehealth_patient_id, body)
  values (p_telehealth_patient_id, v_clinic_body);

  insert into public.notification_outbox (user_id, org_id, type, payload)
  values (
    p_app_user_id,
    p_org_id,
    v_email_type,
    jsonb_build_object('telehealth_patient_id', p_telehealth_patient_id, 'channel', 'account_email')
  );
end;
$$;

create or replace function public._bind_patient_record(
  p_app_user_id uuid,
  p_org_id uuid,
  p_telehealth_patient_id text,
  p_proof_method text
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if exists (
    select 1 from public.patient_record_links
    where app_user_id = p_app_user_id and status = 'active'
  ) then
    raise exception 'already linked' using errcode = '23505';
  end if;

  if exists (
    select 1 from public.patient_record_links
    where telehealth_patient_id = p_telehealth_patient_id and status = 'active'
  ) then
    raise exception 'record already linked' using errcode = '23505';
  end if;

  insert into public.patients (id, org_id)
  values (p_app_user_id, p_org_id)
  on conflict (id) do nothing;

  insert into public.patient_record_links (
    app_user_id, org_id, telehealth_patient_id, status, linked_at, proof_method
  ) values (
    p_app_user_id, p_org_id, p_telehealth_patient_id, 'active', now(), p_proof_method
  );

  perform public._enqueue_link_notices(p_app_user_id, p_org_id, p_telehealth_patient_id, 'linked');

  perform public._audit_log_insert(
    'patient_record_linked',
    p_app_user_id,
    p_app_user_id,
    p_org_id,
    jsonb_build_object(
      'telehealth_patient_id', p_telehealth_patient_id,
      'proof_method', p_proof_method
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Issue codes (service_role / Edge)
-- ---------------------------------------------------------------------------

create or replace function public.issue_telehealth_link_otp(
  p_app_user_id uuid,
  p_telehealth_patient_id text,
  p_org_id uuid,
  p_plain_code text,
  p_ttl_minutes int default 10
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_id uuid;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  update public.patient_link_codes
    set superseded_at = now()
    where issued_to_app_user_id = p_app_user_id
      and method = 'telehealth_otp'
      and used_at is null
      and killed_at is null
      and superseded_at is null;

  insert into public.patient_link_codes (
    telehealth_patient_id, org_id, method, issued_to_app_user_id,
    code_mac, expires_at, created_by
  ) values (
    p_telehealth_patient_id, p_org_id, 'telehealth_otp', p_app_user_id,
    public.link_code_mac(p_plain_code),
    now() + make_interval(mins => p_ttl_minutes),
    'connector'
  ) returning id into v_id;

  insert into public.telehealth_message_outbox (telehealth_patient_id, body)
  values (
    p_telehealth_patient_id,
    'Your Zyndio link code is ready. Not you? Ignore this message.'
  );

  perform public._audit_log_insert(
    'patient_link_otp_issued',
    p_app_user_id, p_app_user_id, p_org_id,
    jsonb_build_object('telehealth_patient_id', p_telehealth_patient_id, 'code_id', v_id)
  );

  return v_id;
end;
$$;

revoke all on function public.issue_telehealth_link_otp(uuid, text, uuid, text, int) from public, anon, authenticated;
grant execute on function public.issue_telehealth_link_otp(uuid, text, uuid, text, int) to service_role;

create or replace function public.issue_clinic_link_code(
  p_telehealth_patient_id text,
  p_org_id uuid,
  p_plain_code text,
  p_created_by text default 'clinic_staff',
  p_ttl_hours int default 72
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_id uuid;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  insert into public.patient_link_codes (
    telehealth_patient_id, org_id, method, issued_to_app_user_id,
    code_mac, expires_at, created_by
  ) values (
    p_telehealth_patient_id, p_org_id, 'clinic_code', null,
    public.link_code_mac(p_plain_code),
    now() + make_interval(hours => p_ttl_hours),
    p_created_by
  ) returning id into v_id;

  perform public._audit_log_insert(
    'patient_clinic_code_issued',
    null, null, p_org_id,
    jsonb_build_object('telehealth_patient_id', p_telehealth_patient_id, 'code_id', v_id, 'created_by', p_created_by)
  );

  return v_id;
end;
$$;

revoke all on function public.issue_clinic_link_code(text, uuid, text, text, int) from public, anon, authenticated;
grant execute on function public.issue_clinic_link_code(text, uuid, text, text, int) to service_role;

-- Ambiguous-match review enqueue (same client response as 0/1 — PSU-TO-14).
create or replace function public.enqueue_patient_link_review(
  p_app_user_id uuid,
  p_org_id uuid,
  p_reason text,
  p_payload jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_id uuid;
begin
  -- Callable from security-definer redeem paths; EXECUTE still revoked from clients.
  insert into public.patient_link_review_queue (app_user_id, org_id, reason, payload)
  values (p_app_user_id, p_org_id, p_reason, coalesce(p_payload, '{}'::jsonb))
  returning id into v_id;

  perform public._audit_log_insert(
    'patient_link_review_enqueued',
    p_app_user_id, p_app_user_id, p_org_id,
    jsonb_build_object('reason', p_reason, 'review_id', v_id)
  );

  return v_id;
end;
$$;

revoke all on function public.enqueue_patient_link_review(uuid, uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.enqueue_patient_link_review(uuid, uuid, text, jsonb) to service_role;

-- ---------------------------------------------------------------------------
-- Redeem telehealth OTP (authenticated patient) — PSU-TO-13 scoped lookup
-- ---------------------------------------------------------------------------

create or replace function public.redeem_telehealth_link_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_uid uuid := auth.uid();
  v_mac text;
  v_row public.patient_link_codes%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if public._patient_link_locked(v_uid) then
    return jsonb_build_object('ok', false, 'error', 'locked');
  end if;

  v_mac := public.link_code_mac(p_code);

  -- Scoped lookup ONLY (PSU-TO-13): never global by code digits.
  select * into v_row
  from public.patient_link_codes c
  where c.issued_to_app_user_id = v_uid
    and c.method = 'telehealth_otp'
    and c.used_at is null
    and c.killed_at is null
    and c.superseded_at is null
    and c.expires_at > now()
    and c.code_mac = v_mac
  for update;

  if not found then
    -- Wrong try against any open OTP for this user (if present).
    update public.patient_link_codes
      set wrong_try_count = wrong_try_count + 1,
          killed_at = case when wrong_try_count + 1 >= 5 then now() else killed_at end
      where issued_to_app_user_id = v_uid
        and method = 'telehealth_otp'
        and used_at is null
        and killed_at is null
        and superseded_at is null
        and expires_at > now();

    perform public._patient_link_register_wrong(v_uid);
    perform public._audit_log_insert(
      'patient_link_otp_rejected',
      v_uid, v_uid, null,
      jsonb_build_object('reason', 'mismatch_or_absent')
    );
    return jsonb_build_object('ok', false, 'error', 'invalid_code');
  end if;

  begin
    perform public._bind_patient_record(
      v_uid, v_row.org_id, v_row.telehealth_patient_id, 'telehealth_otp'
    );
  exception
    when unique_violation then
      perform public._audit_log_insert(
        'patient_link_otp_conflict',
        v_uid, v_uid, null,
        jsonb_build_object('reason', 'unique_violation')
      );
      return jsonb_build_object('ok', false, 'error', 'conflict');
  end;

  update public.patient_link_codes
    set used_at = now()
    where id = v_row.id;
  perform public._patient_link_clear_attempts(v_uid);

  return jsonb_build_object(
    'ok', true,
    'telehealth_patient_id', v_row.telehealth_patient_id,
    'org_id', v_row.org_id
  );
end;
$$;

revoke all on function public.redeem_telehealth_link_code(text) from public, anon;
grant execute on function public.redeem_telehealth_link_code(text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Redeem clinic code
-- ---------------------------------------------------------------------------

create or replace function public.redeem_clinic_link_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_uid uuid := auth.uid();
  v_mac text;
  v_row public.patient_link_codes%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if public._patient_link_locked(v_uid) then
    return jsonb_build_object('ok', false, 'error', 'locked');
  end if;

  if public._clinic_code_breaker_tripped() then
    return jsonb_build_object('ok', false, 'error', 'unavailable');
  end if;

  -- Clinic redeem never takes email/name/DOB (PSU-TO-01..03, TO-11).
  v_mac := public.link_code_mac(p_code);

  select * into v_row
  from public.patient_link_codes c
  where c.method = 'clinic_code'
    and c.code_mac = v_mac
    and c.used_at is null
    and c.killed_at is null
    and c.expires_at > now()
  for update;

  if not found then
    perform public._clinic_code_breaker_bump();
    perform public._patient_link_register_wrong(v_uid);
    perform public._audit_log_insert(
      'patient_clinic_code_rejected',
      v_uid, v_uid, null,
      jsonb_build_object('reason', 'mismatch')
    );
    return jsonb_build_object('ok', false, 'error', 'invalid_code');
  end if;

  begin
    perform public._bind_patient_record(
      v_uid, v_row.org_id, v_row.telehealth_patient_id, 'clinic_code'
    );
  exception
    when unique_violation then
      perform public.enqueue_patient_link_review(
        v_uid, v_row.org_id, 'duplicate_claim',
        jsonb_build_object('telehealth_patient_id', v_row.telehealth_patient_id)
      );
      return jsonb_build_object('ok', false, 'error', 'conflict');
  end;

  update public.patient_link_codes set used_at = now() where id = v_row.id;
  perform public._patient_link_clear_attempts(v_uid);
  return jsonb_build_object(
    'ok', true,
    'telehealth_patient_id', v_row.telehealth_patient_id,
    'org_id', v_row.org_id
  );
end;
$$;

revoke all on function public.redeem_clinic_link_code(text) from public, anon;
grant execute on function public.redeem_clinic_link_code(text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Unlink
-- ---------------------------------------------------------------------------

create or replace function public.unlink_patient_record()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.patient_record_links%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select * into v_row
  from public.patient_record_links
  where app_user_id = v_uid and status = 'active'
  for update;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_linked');
  end if;

  update public.patient_record_links
    set status = 'revoked', revoked_at = now()
    where id = v_row.id;

  -- Kill outstanding codes for this telehealth id.
  update public.patient_link_codes
    set killed_at = coalesce(killed_at, now())
    where telehealth_patient_id = v_row.telehealth_patient_id
      and used_at is null
      and killed_at is null;

  perform public._enqueue_link_notices(
    v_uid, v_row.org_id, v_row.telehealth_patient_id, 'unlinked'
  );

  perform public._audit_log_insert(
    'patient_record_unlinked',
    v_uid, v_uid, v_row.org_id,
    jsonb_build_object('telehealth_patient_id', v_row.telehealth_patient_id)
  );

  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.unlink_patient_record() from public, anon;
grant execute on function public.unlink_patient_record() to authenticated, service_role;

comment on table public.patient_record_links is
  'Active app↔telehealth binding. Partial unique indexes enforce PSU-TO-07/10.';
comment on table public.patient_link_codes is
  'OTP (issued_to_app_user_id NOT NULL) and clinic codes (HMAC only). Never store plaintext.';
