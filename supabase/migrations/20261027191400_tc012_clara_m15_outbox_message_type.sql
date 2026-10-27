-- Clara M15: telehealth_message_outbox holds both redeemable OTP bodies
-- (message_type = 'code') and link/unlink security notices
-- (message_type = 'notice'). Scrub / age-clear only 'code' rows, and mark
-- them scrubbed so the sender never delivers the placeholder "code removed"
-- text to a patient. Notices keep their exact body forever.
-- These rows were never deployed; a new migration is fine.

-- ---------------------------------------------------------------------------
-- 1. message_type column + backfill
-- ---------------------------------------------------------------------------
alter table public.telehealth_message_outbox
  add column if not exists message_type text;

-- Known notice bodies from _enqueue_link_notices; everything else is a code.
update public.telehealth_message_outbox
  set message_type = 'notice'
  where message_type is null
    and body in (
      'Your record was linked to a Zyndio app account. Not you? Contact your clinic.',
      'A Zyndio app account was unlinked from your record. Not you? Contact your clinic.'
    );

update public.telehealth_message_outbox
  set message_type = 'code'
  where message_type is null;

alter table public.telehealth_message_outbox
  alter column message_type set default 'code',
  alter column message_type set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'telehealth_message_outbox_message_type_check'
      and conrelid = 'public.telehealth_message_outbox'::regclass
  ) then
    alter table public.telehealth_message_outbox
      add constraint telehealth_message_outbox_message_type_check
      check (message_type in ('code', 'notice'));
  end if;
end $$;

comment on column public.telehealth_message_outbox.message_type is
  'Clara M15: code = redeemable OTP body (scrub on delivery / 10m age); notice = link/unlink security notice (never scrub).';

-- ---------------------------------------------------------------------------
-- 2. Inserts: OTP → code, link notices → notice
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

  insert into public.telehealth_message_outbox (telehealth_patient_id, body, message_type)
  values (p_telehealth_patient_id, v_clinic_body, 'notice');

  insert into public.notification_outbox (user_id, org_id, type, payload)
  values (
    p_app_user_id,
    p_org_id,
    v_email_type,
    jsonb_build_object('telehealth_patient_id', p_telehealth_patient_id, 'channel', 'account_email')
  );
end;
$$;

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
  insert into public.telehealth_message_outbox (telehealth_patient_id, body, message_type)
  values (
    p_telehealth_patient_id,
    format(
      'Your Zyndio link code is %s. It expires in %s minutes and works once. Not you? Ignore this message.',
      v_code,
      p_ttl_minutes
    ),
    'code'
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
-- 3. Scrub only message_type = 'code' (delivery + age + cron)
-- ---------------------------------------------------------------------------
create or replace function public._scrub_telehealth_outbox_row(p_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  update public.telehealth_message_outbox
    set body = public._telehealth_outbox_scrub_body(body),
        scrubbed_at = now()
    where id = p_id
      and scrubbed_at is null
      and message_type = 'code';
end;
$$;

create or replace function public.mark_telehealth_outbox_delivered(p_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  update public.telehealth_message_outbox
    set delivered_at = coalesce(delivered_at, now())
    where id = p_id;

  -- Notices keep their body; only code rows are scrubbed (Clara M15).
  perform public._scrub_telehealth_outbox_row(p_id);
end;
$$;

create or replace function public.scrub_stale_telehealth_outbox()
returns int
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_count int;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  with scrubbed as (
    update public.telehealth_message_outbox
      set body = public._telehealth_outbox_scrub_body(body),
          scrubbed_at = now()
      where scrubbed_at is null
        and message_type = 'code'
        and created_at < now() - interval '10 minutes'
      returning 1
  )
  select count(*) into v_count from scrubbed;

  return v_count;
end;
$$;

create or replace function public._cron_scrub_stale_telehealth_outbox()
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  update public.telehealth_message_outbox
    set body = public._telehealth_outbox_scrub_body(body),
        scrubbed_at = now()
    where scrubbed_at is null
      and message_type = 'code'
      and created_at < now() - interval '10 minutes';
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Sender query: pending = not yet delivered AND not scrubbed.
--    Scrubbed code rows (body = 'code removed') are excluded so the
--    connector / worker never sends the placeholder to a patient.
-- ---------------------------------------------------------------------------
create or replace function public.list_pending_telehealth_outbox()
returns table (
  id uuid,
  telehealth_patient_id text,
  body text,
  message_type text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  return query
    select o.id, o.telehealth_patient_id, o.body, o.message_type, o.created_at
    from public.telehealth_message_outbox o
    where o.delivered_at is null
      and o.scrubbed_at is null
    order by o.created_at;
end;
$$;

revoke all on function public.list_pending_telehealth_outbox() from public, anon, authenticated;
grant execute on function public.list_pending_telehealth_outbox() to service_role;

comment on function public.list_pending_telehealth_outbox() is
  'Clara M15 sender query: rows waiting to send. Excludes scrubbed code rows so "code removed" is never delivered.';
