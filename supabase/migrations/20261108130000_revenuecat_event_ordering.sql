-- RevenueCat webhook: idempotency and event ordering.
--
-- handle-revenuecat-webhook upserted patient_accounts straight from each event,
-- so (a) RevenueCat's retries and duplicate deliveries were re-applied, and (b)
-- events arriving out of order (they are not guaranteed to be in order) let an
-- older event overwrite a newer one - e.g. a delayed EXPIRATION for last month
-- downgrading a patient who has since renewed. subscription_expires_at was
-- never written either.
--
-- public.apply_revenuecat_event does the whole decision in one transaction:
--   1. record the event id in revenuecat_events; a repeat id is 'duplicate'
--      and changes nothing;
--   2. upsert the patient's premium state only if this event is newer than the
--      last one applied (patient_accounts.subscription_event_at); an older
--      event is recorded but 'stale' and changes nothing.
-- The function is service-role only (the webhook); patients still cannot
-- write any premium column (TC-026 lockdown), including the new
-- subscription_event_at.

alter table public.patient_accounts
  add column if not exists subscription_event_at timestamptz;

-- Column-level privileges are explicit for patient_accounts writes (TC-026);
-- make sure the new column is not writable by clients.
revoke insert (subscription_event_at), update (subscription_event_at)
  on public.patient_accounts from public, anon, authenticated;

create table if not exists public.revenuecat_events (
  event_id text primary key,
  patient_id uuid not null,
  event_type text not null,
  event_at timestamptz not null,
  action text not null,
  outcome text not null,
  received_at timestamptz not null default now(),
  constraint revenuecat_events_event_id_length check (char_length(event_id) between 1 and 200),
  constraint revenuecat_events_event_type_length check (char_length(event_type) between 1 and 64),
  constraint revenuecat_events_action_check check (action in ('grant', 'revoke')),
  constraint revenuecat_events_outcome_check check (outcome in ('applied', 'stale'))
);

create index if not exists revenuecat_events_patient_idx
  on public.revenuecat_events (patient_id, event_at desc);

alter table public.revenuecat_events enable row level security;
alter table public.revenuecat_events force row level security;
revoke all on public.revenuecat_events from public, anon, authenticated;
grant all on public.revenuecat_events to service_role;

create or replace function public.apply_revenuecat_event(
  p_event_id text,
  p_patient_id uuid,
  p_event_type text,
  p_event_at timestamptz,
  p_action text,
  p_expires_at timestamptz
)
returns text
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_rows int;
  v_outcome text;
begin
  if p_event_id is null or p_patient_id is null or p_event_at is null
     or p_action not in ('grant', 'revoke') then
    raise exception 'apply_revenuecat_event: invalid arguments' using errcode = '22023';
  end if;

  -- Serialise events for the same patient so the newer-than check below and
  -- the write it guards cannot interleave with a concurrent delivery.
  perform pg_advisory_xact_lock(hashtextextended('revenuecat:' || p_patient_id::text, 0));

  if exists (select 1 from public.revenuecat_events where event_id = p_event_id) then
    return 'duplicate';
  end if;

  insert into public.patient_accounts as pa
    (patient_id, is_premium, subscription_plan, subscription_expires_at, subscription_event_at, updated_at)
  values
    (p_patient_id,
     p_action = 'grant',
     case when p_action = 'grant' then 'plus' else 'free' end,
     p_expires_at,
     p_event_at,
     now())
  on conflict (patient_id) do update
    set is_premium = excluded.is_premium,
        subscription_plan = excluded.subscription_plan,
        subscription_expires_at = excluded.subscription_expires_at,
        subscription_event_at = excluded.subscription_event_at,
        updated_at = now()
    where pa.subscription_event_at is null
       or pa.subscription_event_at < excluded.subscription_event_at;
  get diagnostics v_rows = row_count;

  v_outcome := case when v_rows > 0 then 'applied' else 'stale' end;

  insert into public.revenuecat_events (event_id, patient_id, event_type, event_at, action, outcome)
  values (p_event_id, p_patient_id, left(p_event_type, 64), p_event_at, p_action, v_outcome);

  return v_outcome;
end;
$$;

revoke all on function public.apply_revenuecat_event(text, uuid, text, timestamptz, text, timestamptz)
  from public, anon, authenticated;
grant execute on function public.apply_revenuecat_event(text, uuid, text, timestamptz, text, timestamptz)
  to service_role;

comment on function public.apply_revenuecat_event(text, uuid, text, timestamptz, text, timestamptz) is
  'Service-role only (handle-revenuecat-webhook): idempotent, newest-event-wins premium update.';
