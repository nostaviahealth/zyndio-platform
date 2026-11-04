-- PRD clause 9.2: every AI-assisted feature sits behind its own kill switch,
-- so if a regulator objects to one we can switch it off for a clinic within a
-- day, without an app release.
--
-- One row per (clinic, feature). org_id null = every clinic. feature '*' =
-- every AI feature. No row means on. The intelligence, embed-memory and
-- search-memory Edge Functions read this with the service role before any
-- model call and refuse with 503 ai_feature_disabled (and fail closed when it
-- can't be read). Operators flip a switch with SQL (runbook in
-- docs/ops/ai-kill-switch.md); every change is audit-logged by trigger.
-- No client grants at all, so the TC-040 allowlist is unchanged.

create table if not exists public.ai_feature_switches (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references public.organizations (id) on delete cascade,
  feature text not null check (feature in
    ('*', 'companion', 'food_analysis', 'lab_extraction', 'coaching', 'memory')),
  enabled boolean not null,
  reason text not null check (char_length(reason) between 3 and 500),
  changed_at timestamptz not null default now()
);

-- At most one row per clinic (or the all-clinics row) per feature.
create unique index if not exists ai_feature_switches_scope_uidx
  on public.ai_feature_switches (coalesce(org_id, '00000000-0000-0000-0000-000000000000'::uuid), feature);

alter table public.ai_feature_switches enable row level security;
alter table public.ai_feature_switches force row level security;
revoke all on public.ai_feature_switches from public, anon, authenticated;

create or replace function public.ai_feature_switches_audit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.ai_feature_switches := coalesce(new, old);
begin
  if tg_op <> 'DELETE' then
    new.changed_at := now();
  end if;
  -- _audit_log_insert, not write_audit_log: operators flip switches from SQL
  -- (no staff JWT), which write_audit_log would refuse. auth.uid() is null then.
  perform public._audit_log_insert(
    'ai_feature_switch_' || lower(tg_op), auth.uid(), null, r.org_id,
    jsonb_build_object('feature', r.feature,
                       'enabled', case when tg_op = 'DELETE' then null else new.enabled end,
                       'reason', r.reason)
  );
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

revoke execute on function public.ai_feature_switches_audit() from public, anon, authenticated;

drop trigger if exists ai_feature_switches_audit on public.ai_feature_switches;
create trigger ai_feature_switches_audit
  before insert or update or delete on public.ai_feature_switches
  for each row execute function public.ai_feature_switches_audit();
