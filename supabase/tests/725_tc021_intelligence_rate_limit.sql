-- TC-021 item 12: per-patient intelligence rate limit - a fixed budget per
-- hour AND per day. public.consume_intelligence_budget(key, hour, day)
-- returns (allowed, retry_after_seconds): when either budget is spent the
-- call is refused (nothing consumed) with the seconds until the blocking
-- window resets, which the function sends as Retry-After on a 429.
--
-- FAILS before the item-12 migration (the function does not exist).
-- Keys are fictional per-file strings; rolled back.
begin;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);

select has_function('public', 'consume_intelligence_budget', array['text', 'integer', 'integer'],
  'consume_intelligence_budget(text, int, int) exists');

select ok(not has_function_privilege('anon', 'public.consume_intelligence_budget(text, integer, integer)', 'execute'),
  'anon cannot execute consume_intelligence_budget');
select ok(not has_function_privilege('authenticated', 'public.consume_intelligence_budget(text, integer, integer)', 'execute'),
  'authenticated cannot execute consume_intelligence_budget (service role only)');
select ok(has_function_privilege('service_role', 'public.consume_intelligence_budget(text, integer, integer)', 'execute'),
  'service_role can execute consume_intelligence_budget');

-- Hourly budget 3 (daily 10): calls 1-3 allowed, call 4 refused.
select is((select allowed from public.consume_intelligence_budget('tc021-725-hour', 3, 10)), true, 'hour budget: call 1 allowed');
select is((select allowed from public.consume_intelligence_budget('tc021-725-hour', 3, 10)), true, 'hour budget: call 2 allowed');
select is((select allowed from public.consume_intelligence_budget('tc021-725-hour', 3, 10)), true, 'hour budget: call 3 allowed');

create temp table r4 as select * from public.consume_intelligence_budget('tc021-725-hour', 3, 10);
select is((select allowed from r4), false, 'hour budget: call 4 refused');
select ok((select retry_after_seconds from r4) between 1 and 3600, 'hour budget: Retry-After is within the hour window');

select is((select count from public.rate_limit_counters where (bucket, key_hash) = ('intelligence_hour', 'tc021-725-hour')), 3,
  'a refused call consumes nothing (hour count stays 3)');
select is((select count from public.rate_limit_counters where (bucket, key_hash) = ('intelligence_day', 'tc021-725-hour')), 3,
  'a refused call consumes nothing (day count stays 3)');

-- Retry-After is the time left in the CURRENT hour window, not a flat hour.
update public.rate_limit_counters set window_start = now() - interval '50 minutes'
  where (bucket, key_hash) = ('intelligence_hour', 'tc021-725-hour');
select ok((select retry_after_seconds from public.consume_intelligence_budget('tc021-725-hour', 3, 10)) between 590 and 600,
  'hour budget: Retry-After counts down to the end of the window (~600 s left)');

-- Once the hour window has passed the hour budget is fresh again.
update public.rate_limit_counters set window_start = now() - interval '61 minutes'
  where (bucket, key_hash) = ('intelligence_hour', 'tc021-725-hour');
select is((select allowed from public.consume_intelligence_budget('tc021-725-hour', 3, 10)), true,
  'hour budget: a new hour window allows calls again');
select is((select count from public.rate_limit_counters where (bucket, key_hash) = ('intelligence_hour', 'tc021-725-hour')), 1,
  'hour budget: the new window starts counting from 1');
select is((select count from public.rate_limit_counters where (bucket, key_hash) = ('intelligence_day', 'tc021-725-hour')), 4,
  'day budget keeps counting across hour windows');

-- Daily budget 2 (hourly 100): call 3 refused even though the hour has room.
select is((select allowed from public.consume_intelligence_budget('tc021-725-day', 100, 2)), true, 'day budget: call 1 allowed');
select is((select allowed from public.consume_intelligence_budget('tc021-725-day', 100, 2)), true, 'day budget: call 2 allowed');
create temp table d3 as select * from public.consume_intelligence_budget('tc021-725-day', 100, 2);
select is((select allowed from d3), false, 'day budget: call 3 refused');
select ok((select retry_after_seconds from d3) between 3601 and 86400, 'day budget: Retry-After points at the end of the day window');
select is((select count from public.rate_limit_counters where (bucket, key_hash) = ('intelligence_hour', 'tc021-725-day')), 2,
  'a day-refused call does not consume the hour budget either');

update public.rate_limit_counters set window_start = now() - interval '25 hours'
  where (bucket, key_hash) = ('intelligence_day', 'tc021-725-day');
select is((select allowed from public.consume_intelligence_budget('tc021-725-day', 100, 2)), true,
  'day budget: a new day window allows calls again');

-- Budgets are per key (per patient): another key is unaffected.
select is((select allowed from public.consume_intelligence_budget('tc021-725-other', 3, 10)), true,
  'another patient key has its own budget');

select * from finish();
rollback;
