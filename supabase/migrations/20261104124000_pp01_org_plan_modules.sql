-- PP-01: clinic tier and module configuration, with a change history that
-- invoices can be pro-rated from.
--
--   * public.plan_modules     - module catalog. kind 'core' modules are always
--     on for the Core tier; kind 'standard' modules are the menu a clinic picks
--     from. The catalog is data, so renaming or adding modules is a migration
--     that touches no code.
--   * public.org_plans        - the clinic's current tier + chosen standard
--     modules (Core tier: up to two standard modules).
--   * public.org_plan_history - append-only billing periods. Every change
--     closes the open period (effective_to = now()) and opens a new one, so
--     periods for a clinic never overlap and an invoice pro-rates by
--     [effective_from, effective_to).
--
-- Only the clinic's org admin (aal2) can change the plan or read the history;
-- every active member of the clinic can read the current plan (the app gates
-- module features on it). Each change writes an 'org_plan_changed' audit row.
-- New clinics start on Core with no standard modules chosen.
-- Tests: supabase/tests/754_pp01_org_plan_modules.sql.

create table public.plan_modules (
  module_key text primary key check (module_key ~ '^[a-z0-9_]{1,40}$'),
  label text not null,
  kind text not null check (kind in ('core', 'standard')),
  sort int not null default 0
);

alter table public.plan_modules enable row level security;
alter table public.plan_modules force row level security;
revoke insert, update, delete on public.plan_modules from anon, authenticated;
grant select on public.plan_modules to authenticated;
create policy plan_modules_read on public.plan_modules
  for select
  to authenticated
  using (true);

-- Catalog (PP-01): Core tier = five core modules + two standard modules of
-- the clinic's choice.
--
-- PLACEHOLDER SEED - NOT CONTRACTUAL. The PRD defers the module list to
-- Schedule B of the agreement, which we do not have. The only module the PRD
-- names is Re-Test Recall (a standard module: 90/180/365-day scan and lab
-- reminders). Every other key below is a working placeholder until Schedule B
-- is confirmed; replace them with a follow-up migration (the catalog is data,
-- no code depends on the specific keys). plan_modules.is_placeholder lets the
-- portal say so on screen.
alter table public.plan_modules add column is_placeholder boolean not null default true;

insert into public.plan_modules (module_key, label, kind, sort) values
  ('patient_app',        'Patient app',            'core',     10),
  ('labs_biomarkers',    'Labs and biomarkers',    'core',     20),
  ('physician_portal',   'Physician portal',       'core',     30),
  ('treatment_context',  'Treatment context',      'core',     40),
  ('notifications',      'Notifications',          'core',     50),
  ('wearables',          'Wearables',              'standard', 110),
  ('nutrition_logging',  'Nutrition logging',      'standard', 120),
  ('ai_companion',       'AI companion',           'standard', 130),
  ('gamification',       'Challenges and points',  'standard', 140),
  ('integration_api',    'Integration API',        'standard', 150),
  ('re_test_recall',     'Re-Test Recall',         'standard', 160);

-- Named in the PRD (USD 50/month standard module); the rest stay placeholders.
update public.plan_modules set is_placeholder = false where module_key = 're_test_recall';

create table public.org_plans (
  org_id uuid primary key references public.organizations (id) on delete cascade,
  tier text not null default 'core' check (tier in ('core')),
  standard_modules text[] not null default '{}',
  effective_from timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete set null,
  updated_at timestamptz not null default now()
);

create table public.org_plan_history (
  id bigint generated always as identity primary key,
  org_id uuid not null references public.organizations (id) on delete cascade,
  tier text not null,
  standard_modules text[] not null,
  effective_from timestamptz not null,
  effective_to timestamptz,
  changed_by uuid references auth.users (id) on delete set null,
  reason text check (reason is null or char_length(reason) <= 300),
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to >= effective_from)
);

create unique index org_plan_history_one_open_idx on public.org_plan_history (org_id) where effective_to is null;
create index org_plan_history_org_idx on public.org_plan_history (org_id, effective_from desc);

alter table public.org_plans enable row level security;
alter table public.org_plans force row level security;
alter table public.org_plan_history enable row level security;
alter table public.org_plan_history force row level security;
revoke insert, update, delete on public.org_plans from anon, authenticated;
revoke insert, update, delete on public.org_plan_history from anon, authenticated;

create policy org_plans_member_select on public.org_plans
  for select
  to authenticated
  using (org_id = public.current_org_id() and public.has_aal2());

create policy org_plan_history_admin_select on public.org_plan_history
  for select
  to authenticated
  using (org_id = public.current_org_id() and public.has_aal2() and public.is_org_admin());

-- Shape rule for a plan: Core tier, at most two distinct standard modules,
-- each one a 'standard' catalog entry.
create function public._enforce_org_plan_shape()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if cardinality(NEW.standard_modules) > 2 then
    raise exception 'the Core tier includes at most two standard modules' using errcode = '22023';
  end if;
  if cardinality(NEW.standard_modules) <> (select count(distinct m) from unnest(NEW.standard_modules) m) then
    raise exception 'standard modules must be distinct' using errcode = '22023';
  end if;
  if exists (
    select 1 from unnest(NEW.standard_modules) m
    where not exists (select 1 from public.plan_modules pm where pm.module_key = m and pm.kind = 'standard')
  ) then
    raise exception 'unknown standard module' using errcode = '22023';
  end if;
  return NEW;
end;
$$;

create trigger trg_org_plan_shape
  before insert or update on public.org_plans
  for each row execute function public._enforce_org_plan_shape();

-- History is append-only: the only update allowed is closing an open period.
create function public._enforce_org_plan_history_append_only()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if TG_OP = 'DELETE' then
    raise exception 'plan history is append-only' using errcode = '42501';
  end if;
  if OLD.effective_to is not null
     or NEW.effective_to is null
     or (NEW.org_id, NEW.tier, NEW.standard_modules, NEW.effective_from, NEW.changed_by, NEW.reason, NEW.created_at)
        is distinct from
        (OLD.org_id, OLD.tier, OLD.standard_modules, OLD.effective_from, OLD.changed_by, OLD.reason, OLD.created_at) then
    raise exception 'plan history is append-only' using errcode = '42501';
  end if;
  return NEW;
end;
$$;

create trigger trg_org_plan_history_append_only
  before update or delete on public.org_plan_history
  for each row execute function public._enforce_org_plan_history_append_only();

-- New clinic -> Core plan + its first open billing period.
create function public._org_plan_default()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  insert into public.org_plans (org_id, tier, standard_modules, effective_from)
  values (NEW.id, 'core', '{}', NEW.created_at)
  on conflict (org_id) do nothing;
  insert into public.org_plan_history (org_id, tier, standard_modules, effective_from)
  select NEW.id, 'core', '{}', NEW.created_at
  where not exists (select 1 from public.org_plan_history h where h.org_id = NEW.id and h.effective_to is null);
  return NEW;
end;
$$;

create trigger trg_org_plan_default
  after insert on public.organizations
  for each row execute function public._org_plan_default();

revoke all on function public._enforce_org_plan_shape() from public, anon, authenticated;
revoke all on function public._enforce_org_plan_history_append_only() from public, anon, authenticated;
revoke all on function public._org_plan_default() from public, anon, authenticated;

-- Backfill existing clinics.
insert into public.org_plans (org_id, tier, standard_modules, effective_from)
select o.id, 'core', '{}', o.created_at from public.organizations o
on conflict (org_id) do nothing;
insert into public.org_plan_history (org_id, tier, standard_modules, effective_from)
select o.id, 'core', '{}', o.created_at from public.organizations o
where not exists (select 1 from public.org_plan_history h where h.org_id = o.id and h.effective_to is null);

-- ---------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------

-- Current plan for any active member of the clinic (aal2).
create function public.get_org_plan()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org uuid := public._portal_gate(
    array['org_admin', 'physician', 'care_coordinator', 'read_only']::public.app_role[]);
  v_plan public.org_plans;
begin
  select * into v_plan from public.org_plans where org_id = v_org;
  return jsonb_build_object(
    'tier', coalesce(v_plan.tier, 'core'),
    'standard_modules', to_jsonb(coalesce(v_plan.standard_modules, '{}'::text[])),
    'effective_from', v_plan.effective_from,
    'max_standard_modules', 2,
    'catalog', (
      select jsonb_agg(jsonb_build_object('module_key', m.module_key, 'label', m.label, 'kind', m.kind,
                                          'is_placeholder', m.is_placeholder)
                       order by m.sort, m.module_key)
      from public.plan_modules m)
  );
end;
$$;

-- Billing periods (org admin only), newest first.
create function public.list_org_plan_history()
returns table (
  id bigint,
  tier text,
  standard_modules text[],
  effective_from timestamptz,
  effective_to timestamptz,
  changed_by_name text,
  reason text
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org uuid := public._portal_gate(array['org_admin']::public.app_role[]);
begin
  return query
    select h.id, h.tier, h.standard_modules, h.effective_from, h.effective_to, m.full_name, h.reason
    from public.org_plan_history h
    left join public.org_members m on m.user_id = h.changed_by and m.org_id = v_org
    where h.org_id = v_org
    order by h.effective_from desc, h.id desc;
end;
$$;

-- Change the plan (org admin only). A no-op change writes nothing.
create function public.set_org_plan(p_tier text, p_standard_modules text[], p_reason text default null)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org uuid := public._portal_gate(array['org_admin']::public.app_role[]);
  v_old public.org_plans;
  v_tier text := lower(btrim(coalesce(p_tier, '')));
  v_modules text[];
  v_now timestamptz := now();
begin
  select coalesce(array_agg(m order by m), '{}') into v_modules
    from (select distinct lower(btrim(x)) as m from unnest(coalesce(p_standard_modules, '{}')) x) s;
  if cardinality(v_modules) <> cardinality(coalesce(p_standard_modules, '{}')) then
    raise exception 'standard modules must be distinct' using errcode = '22023';
  end if;
  if v_tier <> 'core' then
    raise exception 'unknown tier' using errcode = '22023';
  end if;

  select * into v_old from public.org_plans where org_id = v_org for update;
  if v_old.org_id is not null and v_old.tier = v_tier
     and (select coalesce(array_agg(m order by m), '{}') from unnest(v_old.standard_modules) m) = v_modules then
    return;
  end if;

  insert into public.org_plans as p (org_id, tier, standard_modules, effective_from, updated_by, updated_at)
  values (v_org, v_tier, v_modules, v_now, auth.uid(), v_now)
  on conflict (org_id) do update set
    tier = excluded.tier,
    standard_modules = excluded.standard_modules,
    effective_from = excluded.effective_from,
    updated_by = excluded.updated_by,
    updated_at = excluded.updated_at;

  update public.org_plan_history set effective_to = v_now
    where org_id = v_org and effective_to is null;
  insert into public.org_plan_history (org_id, tier, standard_modules, effective_from, changed_by, reason)
  values (v_org, v_tier, v_modules, v_now, auth.uid(), nullif(btrim(p_reason), ''));

  perform public._audit_log_insert('org_plan_changed', auth.uid(), null, v_org,
    jsonb_build_object(
      'from', case when v_old.org_id is null then null
              else jsonb_build_object('tier', v_old.tier, 'standard_modules', to_jsonb(v_old.standard_modules)) end,
      'to', jsonb_build_object('tier', v_tier, 'standard_modules', to_jsonb(v_modules)),
      'effective_from', v_now));
end;
$$;

revoke all on function public.get_org_plan() from public, anon;
revoke all on function public.list_org_plan_history() from public, anon;
revoke all on function public.set_org_plan(text, text[], text) from public, anon;
grant execute on function public.get_org_plan() to authenticated;
grant execute on function public.list_org_plan_history() to authenticated;
grant execute on function public.set_org_plan(text, text[], text) to authenticated;
