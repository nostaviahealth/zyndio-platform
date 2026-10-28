-- TC-012 PSU-RL-03: peek without consuming so login can reject before GoTrue
-- when the IP is already over the failure budget, and only consume on failure.

create or replace function public.peek_rate_limit(
  p_bucket text,
  p_key_hash text,
  p_limit int,
  p_window_seconds int
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select coalesce(
    (
      select c.count < p_limit
        or c.window_start < now() - make_interval(secs => p_window_seconds)
      from public.rate_limit_counters c
      where c.bucket = p_bucket and c.key_hash = p_key_hash
    ),
    true  -- no row yet → allowed
  );
$$;

revoke all on function public.peek_rate_limit(text, text, int, int) from public, anon, authenticated;
grant execute on function public.peek_rate_limit(text, text, int, int) to service_role;

comment on function public.peek_rate_limit(text, text, int, int) is
  'True if check_and_consume_rate_limit would still allow an attempt. Does not increment.';
