-- TC-018 item 6 (L8): schedule the notification_outbox scrub on pg_cron
-- (same 5-minute cadence as the telehealth outbox scrub, tc012_scrub_stale_
-- otp) so a token-bearing row is always scrubbed well inside the 15-minute
-- ceiling even if nothing ever calls process-outbox for it.

create extension if not exists pg_cron with schema extensions;

select cron.unschedule(jobid) from cron.job where jobname = 'tc018_scrub_stale_outbox';

select cron.schedule(
  'tc018_scrub_stale_outbox',
  '*/5 * * * *',
  $$select public._scrub_stale_notification_outbox();$$
);

comment on function public._scrub_stale_notification_outbox() is
  'SECURITY DEFINER, no internal role check (callable at migration time and by pg_cron job tc018_scrub_stale_outbox, every 5m): scrubs the plaintext token from a notification_outbox row once sent or after 15 minutes (TC-018 item 6 / L8).';
