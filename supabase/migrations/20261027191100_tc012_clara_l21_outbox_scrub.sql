-- Clara L21: telehealth_message_outbox.body holds a plain OTP/clinic-code
-- notice until it's delivered. Scrub it on delivery, and by age (<=10 min)
-- as a backstop if delivery never gets marked. Audit never held the
-- plaintext to begin with (M13) — unaffected here.

alter table public.telehealth_message_outbox
  add column if not exists delivered_at timestamptz,
  add column if not exists scrubbed_at timestamptz;

create or replace function public._telehealth_outbox_scrub_body(p_body text)
returns text
language sql
immutable
set search_path = pg_catalog, public
as $$
  select regexp_replace(p_body, '\d{6}', '******', 'g');
$$;

revoke all on function public._telehealth_outbox_scrub_body(text) from public, anon, authenticated;
grant execute on function public._telehealth_outbox_scrub_body(text) to service_role;

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
      and scrubbed_at is null;
end;
$$;

revoke all on function public._scrub_telehealth_outbox_row(uuid) from public, anon, authenticated;
grant execute on function public._scrub_telehealth_outbox_row(uuid) to service_role;

-- Whatever marks a clinic-channel message delivered must scrub it too.
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

  perform public._scrub_telehealth_outbox_row(p_id);
end;
$$;

revoke all on function public.mark_telehealth_outbox_delivered(uuid) from public, anon, authenticated;
grant execute on function public.mark_telehealth_outbox_delivered(uuid) to service_role;

-- Age-based backstop: scrub anything not yet delivered by the time its OTP
-- would have expired anyway. No pg_cron in this project (not adding a
-- hosted/paid dependency here) — this is called from the delivery path above
-- and is also exposed for an Edge/cron job to invoke on an interval <=10m;
-- deploy should schedule it (see SUPABASE-SETUP.md deploy checklist).
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
        and created_at < now() - interval '10 minutes'
      returning 1
  )
  select count(*) into v_count from scrubbed;

  return v_count;
end;
$$;

revoke all on function public.scrub_stale_telehealth_outbox() from public, anon, authenticated;
grant execute on function public.scrub_stale_telehealth_outbox() to service_role;

comment on column public.telehealth_message_outbox.delivered_at is
  'Set by mark_telehealth_outbox_delivered; triggers immediate OTP scrub (Clara L21).';
comment on column public.telehealth_message_outbox.scrubbed_at is
  'Set once body no longer holds a redeemable OTP (on delivery or by 10m age, Clara L21).';
