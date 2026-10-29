-- TC-021 item 12: per-patient rate limit for the intelligence function - a
-- fixed budget per hour AND per day (limits are passed by the function).
--
-- Reuses public.rate_limit_counters (service-role only) with two buckets per
-- patient key: 'intelligence_hour' (3600 s window) and 'intelligence_day'
-- (86400 s window). Both rows are locked in a fixed order (hour, then day),
-- so concurrent calls for one patient serialise and cannot overspend.
-- A refused call consumes nothing and returns the seconds until the blocking
-- window(s) reset, sent to the client as Retry-After on a 429.
create or replace function public.consume_intelligence_budget(
  p_key_hash text,
  p_hour_limit int,
  p_day_limit int
)
returns table (allowed boolean, retry_after_seconds int)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_now timestamptz := now();
  v_hour_start timestamptz;
  v_hour_count int;
  v_day_start timestamptz;
  v_day_count int;
  v_retry int := 0;
begin
  insert into public.rate_limit_counters (bucket, key_hash, window_start, count)
  values ('intelligence_hour', p_key_hash, v_now, 0),
         ('intelligence_day', p_key_hash, v_now, 0)
  on conflict (bucket, key_hash) do nothing;

  select c.window_start, c.count into v_hour_start, v_hour_count
    from public.rate_limit_counters c
   where c.bucket = 'intelligence_hour' and c.key_hash = p_key_hash
     for update;
  select c.window_start, c.count into v_day_start, v_day_count
    from public.rate_limit_counters c
   where c.bucket = 'intelligence_day' and c.key_hash = p_key_hash
     for update;

  if v_hour_start <= v_now - interval '1 hour' then
    v_hour_start := v_now;
    v_hour_count := 0;
  end if;
  if v_day_start <= v_now - interval '1 day' then
    v_day_start := v_now;
    v_day_count := 0;
  end if;

  if v_hour_count >= p_hour_limit then
    v_retry := greatest(v_retry, ceil(extract(epoch from (v_hour_start + interval '1 hour' - v_now)))::int);
  end if;
  if v_day_count >= p_day_limit then
    v_retry := greatest(v_retry, ceil(extract(epoch from (v_day_start + interval '1 day' - v_now)))::int);
  end if;

  if v_retry > 0 or v_hour_count >= p_hour_limit or v_day_count >= p_day_limit then
    -- Refused: keep any window reset, consume nothing.
    update public.rate_limit_counters set window_start = v_hour_start, count = v_hour_count
     where bucket = 'intelligence_hour' and key_hash = p_key_hash;
    update public.rate_limit_counters set window_start = v_day_start, count = v_day_count
     where bucket = 'intelligence_day' and key_hash = p_key_hash;
    return query select false, greatest(v_retry, 1);
    return;
  end if;

  update public.rate_limit_counters set window_start = v_hour_start, count = v_hour_count + 1
   where bucket = 'intelligence_hour' and key_hash = p_key_hash;
  update public.rate_limit_counters set window_start = v_day_start, count = v_day_count + 1
   where bucket = 'intelligence_day' and key_hash = p_key_hash;
  return query select true, 0;
end;
$$;

revoke all on function public.consume_intelligence_budget(text, int, int) from public, anon, authenticated;
grant execute on function public.consume_intelligence_budget(text, int, int) to service_role;
