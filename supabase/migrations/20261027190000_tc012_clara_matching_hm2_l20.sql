-- Clara REVIEW_TC-012_MATCHING: H-M2 Vault pepper, H-M3 bind refusals,
-- M12 active-link-only RLS, M13 OTP in outbox body, L20 configurable breaker.
-- Never commit a real link_code_pepper value.

-- ---------------------------------------------------------------------------
-- H-M2: pepper from Vault only (fail closed). No GUC / hard-coded fallback.
-- ---------------------------------------------------------------------------
create or replace function public._link_code_pepper()
returns text
language plpgsql
stable
security definer
set search_path = pg_catalog, public, vault
as $$
declare
  v_secret text;
begin
  select ds.decrypted_secret into v_secret
  from vault.decrypted_secrets ds
  where ds.name = 'link_code_pepper'
  limit 1;

  if v_secret is null or length(btrim(v_secret)) = 0 then
    raise exception 'link_code_pepper secret is not configured in Vault'
      using errcode = 'P0001';
  end if;

  return v_secret;
end;
$$;

revoke all on function public._link_code_pepper() from public, anon, authenticated;
-- Callable only via link_code_mac / issue RPCs (security definer chain).

comment on function public._link_code_pepper() is
  'HMAC pepper from vault.decrypted_secrets name=link_code_pepper. '
  'Raises if missing — never falls back to GUC or a hard-coded string.';

-- ---------------------------------------------------------------------------
-- M12: clinical access requires an active patient_record_links row.
-- ---------------------------------------------------------------------------
create or replace function public.current_patient_linked()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
    from public.patient_record_links l
    where l.app_user_id = auth.uid()
      and l.status = 'active'
  );
$$;

comment on function public.current_patient_linked() is
  'True only when auth.uid() has an active patient_record_links row. '
  'Clinic-provisioned patients get a link via create_patient_record; '
  'unlink always revokes clinical reads (Clara M12).';

-- Allow clinic_provisioned proof for staff-created patient accounts.
alter table public.patient_record_links
  drop constraint if exists patient_record_links_proof_method_check;

alter table public.patient_record_links
  add constraint patient_record_links_proof_method_check
  check (proof_method = any (array[
    'telehealth_otp'::text,
    'clinic_code'::text,
    'clinic_provisioned'::text
  ]));

-- ---------------------------------------------------------------------------
-- H-M3 + M12: create_patient_record inserts an active link; same staff/admin
-- refusals already present. _bind gets the same refusals.
-- ---------------------------------------------------------------------------
create or replace function public.create_patient_record(
  p_user_id uuid,
  p_display_name text default null,
  p_mrn text default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org_id uuid;
begin
  if not public.has_aal2() or public.current_role() not in ('physician', 'care_coordinator') then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  v_org_id := public.current_org_id();

  if not exists (select 1 from auth.users where id = p_user_id) then
    raise exception 'account not found' using errcode = 'P0002';
  end if;

  if exists (select 1 from public.org_members where user_id = p_user_id) then
    raise exception 'cannot bind a patient record to a staff account' using errcode = '42501';
  end if;

  if exists (select 1 from public.platform_admins where user_id = p_user_id) then
    raise exception 'cannot bind a patient record to a platform admin account' using errcode = '42501';
  end if;

  if public.is_patient_self_signup(p_user_id) then
    raise exception 'cannot create a clinic patient record for a self-signup account'
      using errcode = '42501';
  end if;

  if exists (select 1 from public.patients where id = p_user_id) then
    raise exception 'account already has a patient record' using errcode = '42501';
  end if;

  insert into public.patients (id, org_id, display_name, mrn)
    values (p_user_id, v_org_id, p_display_name, p_mrn);

  insert into public.patient_record_links (
    app_user_id, org_id, telehealth_patient_id, status, linked_at, proof_method
  ) values (
    p_user_id,
    v_org_id,
    'clinic:' || p_user_id::text,
    'active',
    now(),
    'clinic_provisioned'
  );

  perform public._audit_log_insert(
    'patient_created', auth.uid(), p_user_id, v_org_id, '{}'::jsonb
  );
end;
$$;

revoke all on function public.create_patient_record(uuid, text, text) from public;
grant execute on function public.create_patient_record(uuid, text, text) to authenticated;

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
  -- H-M3: same refusals as create_patient_record.
  if exists (select 1 from public.org_members where user_id = p_app_user_id) then
    raise exception 'cannot bind a patient record to a staff account' using errcode = '42501';
  end if;

  if exists (select 1 from public.platform_admins where user_id = p_app_user_id) then
    raise exception 'cannot bind a patient record to a platform admin account'
      using errcode = '42501';
  end if;

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

  perform public._enqueue_link_notices(
    p_app_user_id, p_org_id, p_telehealth_patient_id, 'linked'
  );

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
-- M13: OTP plain code in clinic-message outbox only (never audit/logs).
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
  v_code text := public.normalise_link_code(p_plain_code);
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  if v_code is null or length(v_code) = 0 then
    raise exception 'plain code required' using errcode = '22023';
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
    public.link_code_mac(v_code),
    now() + make_interval(mins => p_ttl_minutes),
    'connector'
  ) returning id into v_id;

  -- Patient-facing clinic message carries the redeemable code (Clara M13).
  insert into public.telehealth_message_outbox (telehealth_patient_id, body)
  values (
    p_telehealth_patient_id,
    format(
      'Your Zyndio link code is %s. It expires in %s minutes and works once. Not you? Ignore this message.',
      v_code,
      p_ttl_minutes
    )
  );

  -- Audit never stores the plain code.
  perform public._audit_log_insert(
    'patient_link_otp_issued',
    p_app_user_id, p_app_user_id, p_org_id,
    jsonb_build_object('telehealth_patient_id', p_telehealth_patient_id, 'code_id', v_id)
  );

  return v_id;
end;
$$;

revoke all on function public.issue_telehealth_link_otp(uuid, text, uuid, text, int)
  from public, anon, authenticated;
grant execute on function public.issue_telehealth_link_otp(uuid, text, uuid, text, int)
  to service_role;

-- ---------------------------------------------------------------------------
-- L20: clinic-code breaker threshold from GUC (default 100 / 15 min).
-- ---------------------------------------------------------------------------
create or replace function public._clinic_code_breaker_threshold()
returns int
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  v_raw text;
  v_n int;
begin
  v_raw := nullif(current_setting('app.clinic_code_breaker_threshold', true), '');
  if v_raw is null then
    return 100; -- documented default (RECORD_MATCHING §7 / Q5)
  end if;
  begin
    v_n := v_raw::int;
  exception
    when others then
      return 100;
  end;
  if v_n < 1 then
    return 100;
  end if;
  return v_n;
end;
$$;

revoke all on function public._clinic_code_breaker_threshold() from public, anon, authenticated;

comment on function public._clinic_code_breaker_threshold() is
  'Clinic-code global failure trip threshold. GUC app.clinic_code_breaker_threshold, '
  'documented default 100 fails per 15-minute window (Clara L20 / Henry Q5).';

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
  return coalesce(v_count, 0) >= public._clinic_code_breaker_threshold();
end;
$$;
