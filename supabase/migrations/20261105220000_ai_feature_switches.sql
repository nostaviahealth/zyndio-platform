-- Clause 9.2. One row per clinic and feature. org_id null means every clinic.
-- feature '*' covers every feature. This candidate does not treat a missing
-- row as enabled: that production default is not decided. The rows inserted
-- below are an explicit synthetic enable so the fictional candidate can run
-- the features until an operator turns one off.

create table if not exists public.ai_feature_switches (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references public.organizations (id) on delete cascade,
  feature text not null check (feature in
    ('*', 'companion', 'food_analysis', 'lab_extraction', 'coaching', 'memory')),
  enabled boolean not null,
  reason text not null check (char_length(reason) between 3 and 500),
  changed_at timestamptz not null default now()
);

create unique index if not exists ai_feature_switches_scope_uidx
  on public.ai_feature_switches (coalesce(org_id, '00000000-0000-0000-0000-000000000000'::uuid), feature);

alter table public.ai_feature_switches enable row level security;
alter table public.ai_feature_switches force row level security;
revoke all on public.ai_feature_switches from public, anon, authenticated, service_role;
grant select on public.ai_feature_switches to service_role;

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
    new.changed_at := pg_catalog.now();
  end if;
  perform public._audit_log_insert(
    'ai_feature_switch_' || pg_catalog.lower(tg_op),
    auth.uid(),
    null,
    r.org_id,
    pg_catalog.jsonb_build_object(
      'feature', r.feature,
      'enabled', case when tg_op = 'DELETE' then null else new.enabled end,
      'reason', r.reason
    )
  );
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

revoke all on function public.ai_feature_switches_audit() from public, anon, authenticated;

drop trigger if exists ai_feature_switches_audit on public.ai_feature_switches;
create trigger ai_feature_switches_audit
  before insert or update or delete on public.ai_feature_switches
  for each row execute function public.ai_feature_switches_audit();

insert into public.ai_feature_switches (org_id, feature, enabled, reason)
select null, feature, true, 'Synthetic candidate explicit enable. Production missing-row policy is undecided.'
from (values ('companion'), ('food_analysis'), ('lab_extraction'), ('coaching'), ('memory')) as features(feature);
