-- TC-018 item 6 (L8, corrected by Clara): notification_outbox never scrubs
-- the plaintext invite/verify-email/password-reset token out of its payload
-- unless process-outbox happens to be invoked (sendNotificationStub already
-- redacts on send - see emailStub.ts) - and nothing schedules that, so a row
-- that's never processed keeps its plaintext token forever. Add an
-- age/status-based scrub, mirroring the telehealth_message_outbox pattern
-- (Clara L21): scrub once the row is no longer pending (an email worker
-- handled it) or after 15 minutes regardless, whichever comes first. The
-- same function is the one-time backfill for rows that already exist
-- (mirrors _backfill_clinic_provisioned_links: no internal role check, so
-- migrations/pg_cron can call it directly; access from the client/RPC layer
-- is still locked down by revoke/grant).

alter table public.notification_outbox
  add column if not exists scrubbed_at timestamptz;

create or replace function public._notification_outbox_scrub_payload(p_type text, p_payload jsonb)
returns jsonb
language sql
immutable
set search_path = pg_catalog, public
as $$
  select case
    when p_type = any (array['invite', 'verify_email', 'password_reset'])
         and p_payload ? 'token'
    then p_payload || jsonb_build_object('token', null)
    else p_payload
  end;
$$;

revoke all on function public._notification_outbox_scrub_payload(text, jsonb) from public, anon, authenticated;
grant execute on function public._notification_outbox_scrub_payload(text, jsonb) to service_role;

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
        and type = any (array['invite', 'verify_email', 'password_reset'])
        and payload ? 'token'
        and (status <> 'pending' or created_at < now() - interval '15 minutes')
      returning 1
  )
  select count(*) into v_count from scrubbed;

  return v_count;
end;
$$;

revoke all on function public._scrub_stale_notification_outbox() from public, anon, authenticated;
grant execute on function public._scrub_stale_notification_outbox() to service_role;

comment on column public.notification_outbox.scrubbed_at is
  'Set once payload.token no longer holds a redeemable value (on send or by 15m age, TC-018 item 6 / L8).';

-- One-time backfill for rows that already exist.
select public._scrub_stale_notification_outbox();
