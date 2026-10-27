-- Clara L21: pg_cron schedules the stale-OTP outbox scrub every 5 minutes.
begin;
select no_plan();

select ok(
  exists (
    select 1 from cron.job where jobname = 'tc012_scrub_stale_otp'
  ),
  'L21 cron: tc012_scrub_stale_otp job is scheduled'
);

select is(
  (select schedule from cron.job where jobname = 'tc012_scrub_stale_otp'),
  '*/5 * * * *',
  'L21 cron: tc012_scrub_stale_otp runs every 5 minutes'
);

select ok(
  (select command from cron.job where jobname = 'tc012_scrub_stale_otp')
    like '%scrub_stale_telehealth_outbox%',
  'L21 cron: tc012_scrub_stale_otp command invokes the stale-OTP scrub'
);

select finish();
rollback;
