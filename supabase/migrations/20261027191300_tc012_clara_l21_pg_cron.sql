-- Clara L21: schedule the stale-OTP outbox scrub via pg_cron instead of
-- relying on an external Edge/cron job to call scrub_stale_telehealth_outbox()
-- on an interval. pg_cron runs scheduled commands as the bootstrap/postgres
-- role, not service_role, so scrub_stale_telehealth_outbox()'s
-- `auth.role() = service_role` check would reject it directly. Wrap it in a
-- SECURITY DEFINER helper that cron can call, without opening execute to
-- anon/authenticated.

create extension if not exists pg_cron with schema extensions;

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
      and created_at < now() - interval '10 minutes';
end;
$$;

revoke all on function public._cron_scrub_stale_telehealth_outbox() from public, anon, authenticated;
-- pg_cron jobs run as the role that scheduled them (postgres here), so no
-- explicit grant to that role is required; keep it locked down otherwise.

-- Idempotent: drop any prior schedule under this name before (re)scheduling,
-- so re-running this migration (or a future edit to it) doesn't double-book.
select cron.unschedule(jobid) from cron.job where jobname = 'tc012_scrub_stale_otp';

select cron.schedule(
  'tc012_scrub_stale_otp',
  '*/5 * * * *',
  $$select public._cron_scrub_stale_telehealth_outbox();$$
);

comment on function public._cron_scrub_stale_telehealth_outbox() is
  'SECURITY DEFINER wrapper so pg_cron (job tc012_scrub_stale_otp, every 5m) can run the Clara L21 stale-OTP scrub without service_role.';
