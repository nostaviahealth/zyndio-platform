-- INT-02: schedule the webhook delivery worker and the partner-API cleanup.
--
-- * int02_kick_webhook_worker (every minute): if any delivery is due, POST to
--   the deliver-webhooks Edge Function via pg_net. The function URL and the
--   service-role key come from Vault (webhook_worker_url,
--   webhook_worker_service_key) and are set per environment at deploy time -
--   never committed. Missing secrets => the job does nothing but raise a
--   NOTICE (fails closed: nothing is sent, deliveries stay pending and are
--   picked up once configured). The 1-minute cadence is the floor for the
--   first retry (1 min) and the worker also drains anything already due.
-- * int01_partner_api_cleanup (hourly): drop access tokens a day past expiry
--   and idempotency keys past their 7-day window.

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

create or replace function public._cron_kick_webhook_worker()
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, vault
as $$
declare
  v_url text;
  v_key text;
begin
  if not exists (
    select 1 from public.webhook_deliveries
     where status = 'pending' and next_attempt_at <= now()
       and (locked_until is null or locked_until < now())
     limit 1
  ) then
    return;
  end if;

  select ds.decrypted_secret into v_url from vault.decrypted_secrets ds where ds.name = 'webhook_worker_url' limit 1;
  select ds.decrypted_secret into v_key from vault.decrypted_secrets ds where ds.name = 'webhook_worker_service_key' limit 1;
  if v_url is null or v_key is null or btrim(v_url) = '' or btrim(v_key) = '' then
    raise notice 'INT-02: webhook_worker_url / webhook_worker_service_key not set in Vault; deliveries stay pending';
    return;
  end if;

  perform net.http_post(
    url := v_url,
    body := '{}'::jsonb,
    headers := jsonb_build_object('Authorization', 'Bearer ' || v_key, 'Content-Type', 'application/json'),
    timeout_milliseconds := 55000
  );
end;
$$;

create or replace function public._cron_partner_api_cleanup()
returns void
language sql
security definer
set search_path = pg_catalog, public
as $$
  delete from public.api_access_tokens where expires_at < now() - interval '1 day';
  delete from public.api_idempotency_keys where expires_at < now();
$$;

revoke all on function public._cron_kick_webhook_worker() from public, anon, authenticated;
revoke all on function public._cron_partner_api_cleanup() from public, anon, authenticated;
grant execute on function public._cron_kick_webhook_worker() to service_role;
grant execute on function public._cron_partner_api_cleanup() to service_role;

select cron.unschedule(jobid) from cron.job where jobname in ('int02_kick_webhook_worker', 'int01_partner_api_cleanup');

select cron.schedule('int02_kick_webhook_worker', '* * * * *', $$select public._cron_kick_webhook_worker();$$);
select cron.schedule('int01_partner_api_cleanup', '17 * * * *', $$select public._cron_partner_api_cleanup();$$);
