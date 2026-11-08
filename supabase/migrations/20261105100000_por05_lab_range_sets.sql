-- POR-05: versioned, physician-approved reference-range sets per clinic.
--
--   * public.lab_range_sets       - one row per version of a clinic's range set.
--     Lifecycle: draft -> approved (live) -> superseded, or draft -> discarded.
--     At most one draft and at most one live (approved) set per clinic.
--   * public.lab_range_set_items  - analyte / sex / low / high / unit rows of a
--     set. Editable only while the set is a draft; an approved or superseded
--     set is frozen (trigger-enforced, so even a service_role write cannot
--     change what a physician approved).
--
-- Writes go only through the SECURITY DEFINER RPCs below (physician, aal2,
-- own clinic) and every change writes an audit row. Clients get SELECT
-- through RLS and no INSERT/UPDATE/DELETE grant.
--
-- Biomarker flags use the live set: patient_latest_results, patient_trend and
-- the roster rollup (refresh_roster_summary[_all]) now take low/high from the
-- clinic's approved set when it has a row for the analyte (matching unit,
-- the patient's sex preferred over 'any') and recompute the in/out status from
-- it. Without an approved row the stored default range and status are used as
-- before, and range_source = 'default' tells the portal to keep showing the
-- default-range caveat. Approving a set refreshes the clinic's roster rollup.
-- Tests: supabase/tests/770_por05_lab_range_sets.sql.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.lab_range_sets (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  version int not null check (version > 0),
  status text not null default 'draft'
    check (status in ('draft', 'approved', 'superseded', 'discarded')),
  note text check (note is null or char_length(note) <= 500),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  approved_by uuid references auth.users (id) on delete set null,
  approved_at timestamptz,
  closed_at timestamptz,
  unique (org_id, version),
  check ((status in ('approved', 'superseded')) = (approved_at is not null))
);

create unique index lab_range_sets_one_draft_idx on public.lab_range_sets (org_id) where status = 'draft';
create unique index lab_range_sets_one_live_idx on public.lab_range_sets (org_id) where status = 'approved';

create table public.lab_range_set_items (
  id uuid primary key default gen_random_uuid(),
  range_set_id uuid not null references public.lab_range_sets (id) on delete cascade,
  org_id uuid not null references public.organizations (id) on delete cascade,
  analyte_key text not null check (analyte_key ~ '^[a-z0-9_]{1,64}$'),
  analyte_label text not null check (char_length(btrim(analyte_label)) between 1 and 80),
  sex text not null default 'any' check (sex in ('any', 'female', 'male')),
  low numeric,
  high numeric,
  unit text not null check (char_length(btrim(unit)) between 1 and 32),
  updated_at timestamptz not null default now(),
  check (low is not null or high is not null),
  check (low is null or high is null or low < high),
  unique (range_set_id, analyte_key, sex)
);

create index lab_range_set_items_lookup_idx on public.lab_range_set_items (range_set_id, analyte_key);
create index lab_range_set_items_org_id_idx on public.lab_range_set_items (org_id);

alter table public.lab_range_sets enable row level security;
alter table public.lab_range_sets force row level security;
alter table public.lab_range_set_items enable row level security;
alter table public.lab_range_set_items force row level security;

revoke insert, update, delete on public.lab_range_sets from anon, authenticated;
revoke insert, update, delete on public.lab_range_set_items from anon, authenticated;

-- Same visibility as lab_results: clinical staff of the clinic at aal2. The
-- org admin manages users and the plan only (Henry: least privilege).
create policy lab_range_sets_staff_select on public.lab_range_sets
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator', 'read_only')
  );

create policy lab_range_set_items_staff_select on public.lab_range_set_items
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator', 'read_only')
  );

-- ---------------------------------------------------------------------------
-- Invariants (triggers): approved sets are frozen; lifecycle moves one way.
-- ---------------------------------------------------------------------------

create function public._enforce_lab_range_set_lifecycle()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if TG_OP = 'DELETE' then
    raise exception 'range sets are never deleted' using errcode = '42501';
  end if;
  if NEW.org_id <> OLD.org_id or NEW.version <> OLD.version then
    raise exception 'range set org and version are immutable' using errcode = '42501';
  end if;
  if NEW.status <> OLD.status and not (
       (OLD.status = 'draft' and NEW.status in ('approved', 'discarded'))
       or (OLD.status = 'approved' and NEW.status = 'superseded')
     ) then
    raise exception 'range set cannot move from % to %', OLD.status, NEW.status using errcode = '42501';
  end if;
  if OLD.status <> 'draft' and (NEW.note is distinct from OLD.note
       or NEW.approved_by is distinct from OLD.approved_by
       or NEW.approved_at is distinct from OLD.approved_at) then
    raise exception 'an approved range set is frozen' using errcode = '42501';
  end if;
  return NEW;
end;
$$;

create trigger trg_lab_range_set_lifecycle
  before update or delete on public.lab_range_sets
  for each row execute function public._enforce_lab_range_set_lifecycle();

create function public._enforce_lab_range_item_draft_only()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_set public.lab_range_sets;
  v_row public.lab_range_set_items := case when TG_OP = 'DELETE' then OLD else NEW end;
begin
  select * into v_set from public.lab_range_sets where id = v_row.range_set_id;
  -- A cascade delete of the whole clinic removes the set first; let it go.
  if v_set.id is null then
    return v_row;
  end if;
  if v_set.status <> 'draft' then
    raise exception 'only a draft range set can be edited' using errcode = '42501';
  end if;
  if v_row.org_id <> v_set.org_id then
    raise exception 'range item org must match its set' using errcode = '42501';
  end if;
  if TG_OP = 'UPDATE' and NEW.range_set_id <> OLD.range_set_id then
    raise exception 'range item cannot move between sets' using errcode = '42501';
  end if;
  return v_row;
end;
$$;

create trigger trg_lab_range_item_draft_only
  before insert or update or delete on public.lab_range_set_items
  for each row execute function public._enforce_lab_range_item_draft_only();

revoke all on function public._enforce_lab_range_set_lifecycle() from public, anon, authenticated;
revoke all on function public._enforce_lab_range_item_draft_only() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Internal gate shared by the portal's SECURITY DEFINER RPCs (POR-03..06):
-- signed in, aal2, active member of a clinic, role in p_roles. Returns the
-- caller's org id or raises 42501. Not client-callable.
-- ---------------------------------------------------------------------------

create function public._portal_gate(p_roles public.app_role[])
returns uuid
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org uuid := public.current_org_id();
begin
  if auth.uid() is null or v_org is null or not public.has_aal2()
     or not (public.current_role() = any (p_roles)) then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  return v_org;
end;
$$;

revoke all on function public._portal_gate(public.app_role[]) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Effective range + status. Both are pure lookups/computations, safe to call
-- from the SECURITY INVOKER read RPCs (RLS scopes the range lookup to the
-- caller's clinic; a patient session sees no set and keeps stored values).
-- ---------------------------------------------------------------------------

create function public.lab_effective_range(
  p_org_id uuid,
  p_patient_id uuid,
  p_analyte_key text,
  p_unit text
)
returns table (range_low numeric, range_high numeric, range_set_version int)
language sql
stable
security invoker
set search_path = pg_catalog, public
as $$
  select i.low, i.high, s.version
  from public.lab_range_sets s
  join public.lab_range_set_items i on i.range_set_id = s.id
  left join public.patient_roster_meta m on m.patient_id = p_patient_id
  where s.org_id = p_org_id
    and s.status = 'approved'
    and i.analyte_key = p_analyte_key
    and lower(btrim(i.unit)) = lower(btrim(coalesce(p_unit, '')))
    and (
      i.sex = 'any'
      or i.sex = case lower(left(btrim(coalesce(m.sex, '')), 1))
                   when 'f' then 'female' when 'm' then 'male' end
    )
  order by (i.sex = 'any')
  limit 1;
$$;

create function public.lab_effective_status(
  p_stored text,
  p_is_unmapped boolean,
  p_value numeric,
  p_has_approved boolean,
  p_low numeric,
  p_high numeric
)
returns text
language sql
immutable
set search_path = pg_catalog
as $$
  select case
    when not coalesce(p_has_approved, false)
      or p_stored = 'needs_review'
      or coalesce(p_is_unmapped, false)
      or p_value is null then p_stored
    when (p_low is not null and p_value < p_low) or (p_high is not null and p_value > p_high) then 'outside_range'
    when p_stored = 'baseline' then 'baseline'
    else 'within_range'
  end;
$$;

grant execute on function public.lab_effective_range(uuid, uuid, text, text) to authenticated;
grant execute on function public.lab_effective_status(text, boolean, numeric, boolean, numeric, numeric) to authenticated;

-- ---------------------------------------------------------------------------
-- Read RPCs: patient_latest_results / patient_trend gain range_source
-- ('approved' | 'default' | 'none') and range_set_version so the portal can
-- show the default-range caveat only when the range is not from an approved
-- set. The return type changes, so these are dropped and re-created (and
-- re-granted; test 747 pins the grant).
-- ---------------------------------------------------------------------------

drop function public.patient_latest_results(uuid);
create function public.patient_latest_results(p_patient_id uuid)
returns table (
  analyte_key text,
  analyte_label text,
  value numeric,
  original_value numeric,
  unit text,
  status text,
  is_unmapped boolean,
  range_low numeric,
  range_high numeric,
  taken_at timestamptz,
  range_source text,
  range_set_version int
)
language sql
stable
security invoker
set search_path = pg_catalog, public
as $$
  select
    l.analyte_key, l.analyte_label, l.value, l.original_value, l.unit,
    public.lab_effective_status(l.status, l.is_unmapped, l.value, er.range_set_version is not null, er.range_low, er.range_high),
    l.is_unmapped,
    case when er.range_set_version is not null then er.range_low else l.range_low end,
    case when er.range_set_version is not null then er.range_high else l.range_high end,
    l.taken_at,
    case
      when er.range_set_version is not null then 'approved'
      when l.range_low is not null or l.range_high is not null then 'default'
      else 'none'
    end,
    er.range_set_version
  from (
    -- Unchanged row choice (20261029150000): latest per marker, identity-held
    -- reports and corrected originals excluded, ties broken on id.
    select distinct on (lr.analyte_key)
      lr.org_id, lr.analyte_key, lr.analyte_label, lr.value, lr.original_value, lr.unit,
      lr.status, lr.is_unmapped, lr.range_low, lr.range_high, lr.taken_at
    from public.lab_results lr
    where lr.patient_id = p_patient_id
      and not public.lab_report_held(lr.lab_report_id)
      and lr.original_value is null
    order by lr.analyte_key, lr.taken_at desc, lr.id desc
  ) l
  left join lateral public.lab_effective_range(l.org_id, p_patient_id, l.analyte_key, l.unit) er on true
  order by l.analyte_key;
$$;

drop function public.patient_trend(uuid, text, text);
create function public.patient_trend(
  p_patient_id uuid,
  p_analyte text,
  p_period text default '6M'
)
returns table (
  taken_at timestamptz,
  value numeric,
  original_value numeric,
  unit text,
  status text,
  range_low numeric,
  range_high numeric,
  range_source text
)
language sql
stable
security invoker
set search_path = pg_catalog, public
as $$
  select
    lr.taken_at, lr.value, lr.original_value, lr.unit,
    public.lab_effective_status(lr.status, lr.is_unmapped, lr.value, er.range_set_version is not null, er.range_low, er.range_high),
    case when er.range_set_version is not null then er.range_low else lr.range_low end,
    case when er.range_set_version is not null then er.range_high else lr.range_high end,
    case
      when er.range_set_version is not null then 'approved'
      when lr.range_low is not null or lr.range_high is not null then 'default'
      else 'none'
    end
  from public.lab_results lr
  left join lateral public.lab_effective_range(lr.org_id, p_patient_id, lr.analyte_key, lr.unit) er on true
  where lr.patient_id = p_patient_id
    and lr.analyte_key = p_analyte
    and lr.status <> 'needs_review'
    and not lr.is_unmapped
    and not public.lab_report_held(lr.lab_report_id)
    and lr.taken_at >= case upper(coalesce(p_period, '6M'))
      when '3M' then now() - interval '3 months'
      when '6M' then now() - interval '6 months'
      when '1Y' then now() - interval '12 months'
      when 'ALL' then '-infinity'::timestamptz
      else now() - interval '6 months'
    end
  order by lr.taken_at;
$$;

revoke all on function public.patient_latest_results(uuid) from public, anon;
revoke all on function public.patient_trend(uuid, text, text) from public, anon;
grant execute on function public.patient_latest_results(uuid) to authenticated;
grant execute on function public.patient_trend(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Roster rollup: "Outside range" uses the effective (approved-set) status.
-- Only the lo lateral changes from 20261029150000; every other column is
-- byte-identical.
-- ---------------------------------------------------------------------------

create or replace function public.refresh_roster_summary(p_patient_id uuid)
returns void
language sql
security definer
set search_path = pg_catalog, public
as $$
  insert into public.patient_roster_summary as s (
    patient_id, org_id, latest_lab_at,
    has_outside_range, has_needs_review, has_identity_hold, has_any_labs, has_treatment
  )
  select
    p.id, p.org_id,
    la.latest_lab_at,
    coalesce(lo.has_outside_range, false),
    coalesce(la.has_needs_review, false),
    coalesce(la.has_identity_hold, false),
    coalesce(la.has_any_labs, false),
    coalesce(tr.has_treatment, false)
  from public.patients p
  left join lateral (
    select
      max(lr.taken_at) filter (where not public.lab_report_held_unscoped(lr.lab_report_id)) as latest_lab_at,
      bool_or(lr.status = 'needs_review' and not public.lab_report_held_unscoped(lr.lab_report_id)) as has_needs_review,
      bool_or(public.lab_report_held_unscoped(lr.lab_report_id)) as has_identity_hold,
      count(lr.id) filter (where not public.lab_report_held_unscoped(lr.lab_report_id)) > 0 as has_any_labs
    from public.lab_results lr
    where lr.patient_id = p.id
  ) la on true
  left join lateral (
    -- Same rows and same effective status as public.patient_latest_results().
    select bool_or(
      public.lab_effective_status(l.status, l.is_unmapped, l.value, er.range_set_version is not null, er.range_low, er.range_high)
        = 'outside_range'
    ) as has_outside_range
    from (
      select distinct on (lr.analyte_key) lr.analyte_key, lr.status, lr.is_unmapped, lr.value, lr.unit
      from public.lab_results lr
      where lr.patient_id = p.id
        and not public.lab_report_held_unscoped(lr.lab_report_id)
        and lr.original_value is null
      order by lr.analyte_key, lr.taken_at desc, lr.id desc
    ) l
    left join lateral public.lab_effective_range(p.org_id, p.id, l.analyte_key, l.unit) er on true
  ) lo on true
  left join lateral (
    select true as has_treatment
    from public.patient_treatments t
    where t.patient_id = p.id
    limit 1
  ) tr on true
  where p.id = p_patient_id
  on conflict (patient_id) do update set
    org_id            = excluded.org_id,
    latest_lab_at     = excluded.latest_lab_at,
    has_outside_range = excluded.has_outside_range,
    has_needs_review  = excluded.has_needs_review,
    has_identity_hold = excluded.has_identity_hold,
    has_any_labs      = excluded.has_any_labs,
    has_treatment     = excluded.has_treatment;
$$;

create or replace function public.refresh_roster_summary_all()
returns void
language sql
security definer
set search_path = pg_catalog, public
as $$
  insert into public.patient_roster_summary as s (
    patient_id, org_id, latest_lab_at,
    has_outside_range, has_needs_review, has_identity_hold, has_any_labs, has_treatment
  )
  select
    p.id, p.org_id,
    la.latest_lab_at,
    coalesce(lo.has_outside_range, false),
    coalesce(la.has_needs_review, false),
    coalesce(la.has_identity_hold, false),
    coalesce(la.has_any_labs, false),
    coalesce(tr.has_treatment, false)
  from public.patients p
  left join lateral (
    select
      max(lr.taken_at) filter (where not public.lab_report_held_unscoped(lr.lab_report_id)) as latest_lab_at,
      bool_or(lr.status = 'needs_review' and not public.lab_report_held_unscoped(lr.lab_report_id)) as has_needs_review,
      bool_or(public.lab_report_held_unscoped(lr.lab_report_id)) as has_identity_hold,
      count(lr.id) filter (where not public.lab_report_held_unscoped(lr.lab_report_id)) > 0 as has_any_labs
    from public.lab_results lr
    where lr.patient_id = p.id
  ) la on true
  left join lateral (
    select bool_or(
      public.lab_effective_status(l.status, l.is_unmapped, l.value, er.range_set_version is not null, er.range_low, er.range_high)
        = 'outside_range'
    ) as has_outside_range
    from (
      select distinct on (lr.analyte_key) lr.analyte_key, lr.status, lr.is_unmapped, lr.value, lr.unit
      from public.lab_results lr
      where lr.patient_id = p.id
        and not public.lab_report_held_unscoped(lr.lab_report_id)
        and lr.original_value is null
      order by lr.analyte_key, lr.taken_at desc, lr.id desc
    ) l
    left join lateral public.lab_effective_range(p.org_id, p.id, l.analyte_key, l.unit) er on true
  ) lo on true
  left join lateral (
    select true as has_treatment
    from public.patient_treatments t
    where t.patient_id = p.id
    limit 1
  ) tr on true
  on conflict (patient_id) do update set
    org_id            = excluded.org_id,
    latest_lab_at     = excluded.latest_lab_at,
    has_outside_range = excluded.has_outside_range,
    has_needs_review  = excluded.has_needs_review,
    has_identity_hold = excluded.has_identity_hold,
    has_any_labs      = excluded.has_any_labs,
    has_treatment     = excluded.has_treatment;
$$;

-- ---------------------------------------------------------------------------
-- Portal RPCs (SECURITY DEFINER, explicit org scope, audited writes).
-- Reads: physician / care_coordinator / read_only. Writes: physician only.
-- ---------------------------------------------------------------------------

create function public.list_range_sets()
returns table (
  id uuid,
  version int,
  status text,
  note text,
  item_count int,
  created_by_name text,
  created_at timestamptz,
  approved_by_name text,
  approved_at timestamptz,
  closed_at timestamptz
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org uuid := public._portal_gate(array['physician', 'care_coordinator', 'read_only']::public.app_role[]);
begin
  return query
    select s.id, s.version, s.status, s.note,
      (select count(*)::int from public.lab_range_set_items i where i.range_set_id = s.id),
      cb.full_name, s.created_at, ab.full_name, s.approved_at, s.closed_at
    from public.lab_range_sets s
    left join public.org_members cb on cb.user_id = s.created_by and cb.org_id = v_org
    left join public.org_members ab on ab.user_id = s.approved_by and ab.org_id = v_org
    where s.org_id = v_org
    order by s.version desc;
end;
$$;

create function public.get_range_set_items(p_set_id uuid)
returns table (
  id uuid,
  analyte_key text,
  analyte_label text,
  sex text,
  low numeric,
  high numeric,
  unit text,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org uuid := public._portal_gate(array['physician', 'care_coordinator', 'read_only']::public.app_role[]);
begin
  if not exists (select 1 from public.lab_range_sets s where s.id = p_set_id and s.org_id = v_org) then
    raise exception 'range set not found' using errcode = 'P0002';
  end if;
  return query
    select i.id, i.analyte_key, i.analyte_label, i.sex, i.low, i.high, i.unit, i.updated_at
    from public.lab_range_set_items i
    where i.range_set_id = p_set_id and i.org_id = v_org
    order by i.analyte_label, i.analyte_key, i.sex;
end;
$$;

-- New draft = next version, pre-filled with the live set's rows (if any).
create function public.create_range_set_draft(p_note text default null)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org uuid := public._portal_gate(array['physician']::public.app_role[]);
  v_live public.lab_range_sets;
  v_version int;
  v_id uuid;
begin
  -- Serialise version allocation per clinic.
  perform pg_advisory_xact_lock(hashtextextended('lab_range_sets:' || v_org::text, 0));
  if exists (select 1 from public.lab_range_sets where org_id = v_org and status = 'draft') then
    raise exception 'a draft range set already exists' using errcode = 'P0001';
  end if;
  select * into v_live from public.lab_range_sets where org_id = v_org and status = 'approved';
  select coalesce(max(version), 0) + 1 into v_version from public.lab_range_sets where org_id = v_org;

  insert into public.lab_range_sets (org_id, version, status, note, created_by)
  values (v_org, v_version, 'draft', nullif(btrim(p_note), ''), auth.uid())
  returning id into v_id;

  if v_live.id is not null then
    insert into public.lab_range_set_items (range_set_id, org_id, analyte_key, analyte_label, sex, low, high, unit)
    select v_id, v_org, i.analyte_key, i.analyte_label, i.sex, i.low, i.high, i.unit
    from public.lab_range_set_items i
    where i.range_set_id = v_live.id;
  end if;

  perform public._audit_log_insert('range_set_draft_created', auth.uid(), null, v_org,
    jsonb_build_object('range_set_id', v_id, 'version', v_version, 'copied_from_version', v_live.version));
  return v_id;
end;
$$;

create function public.upsert_range_set_item(
  p_set_id uuid,
  p_analyte_key text,
  p_analyte_label text,
  p_sex text,
  p_low numeric,
  p_high numeric,
  p_unit text
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org uuid := public._portal_gate(array['physician']::public.app_role[]);
  v_set public.lab_range_sets;
  v_before public.lab_range_set_items;
  v_id uuid;
  v_key text := lower(btrim(coalesce(p_analyte_key, '')));
  v_sex text := lower(btrim(coalesce(p_sex, 'any')));
begin
  select * into v_set from public.lab_range_sets where id = p_set_id and org_id = v_org for update;
  if v_set.id is null then
    raise exception 'range set not found' using errcode = 'P0002';
  end if;
  if v_set.status <> 'draft' then
    raise exception 'only a draft range set can be edited' using errcode = 'P0001';
  end if;

  select * into v_before from public.lab_range_set_items
    where range_set_id = p_set_id and analyte_key = v_key and sex = v_sex;

  insert into public.lab_range_set_items as i (range_set_id, org_id, analyte_key, analyte_label, sex, low, high, unit)
  values (p_set_id, v_org, v_key, btrim(p_analyte_label), v_sex, p_low, p_high, btrim(p_unit))
  on conflict (range_set_id, analyte_key, sex) do update set
    analyte_label = excluded.analyte_label,
    low = excluded.low,
    high = excluded.high,
    unit = excluded.unit,
    updated_at = now()
  returning i.id into v_id;

  perform public._audit_log_insert('range_set_item_saved', auth.uid(), null, v_org,
    jsonb_build_object(
      'range_set_id', p_set_id, 'version', v_set.version, 'analyte_key', v_key, 'sex', v_sex,
      'before', case when v_before.id is null then null
                else jsonb_build_object('low', v_before.low, 'high', v_before.high, 'unit', v_before.unit) end,
      'after', jsonb_build_object('low', p_low, 'high', p_high, 'unit', btrim(p_unit))));
  return v_id;
end;
$$;

create function public.delete_range_set_item(p_item_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org uuid := public._portal_gate(array['physician']::public.app_role[]);
  v_item public.lab_range_set_items;
  v_set public.lab_range_sets;
begin
  select * into v_item from public.lab_range_set_items where id = p_item_id and org_id = v_org;
  if v_item.id is null then
    raise exception 'range item not found' using errcode = 'P0002';
  end if;
  select * into v_set from public.lab_range_sets where id = v_item.range_set_id for update;
  if v_set.status <> 'draft' then
    raise exception 'only a draft range set can be edited' using errcode = 'P0001';
  end if;
  delete from public.lab_range_set_items where id = p_item_id;
  perform public._audit_log_insert('range_set_item_deleted', auth.uid(), null, v_org,
    jsonb_build_object('range_set_id', v_set.id, 'version', v_set.version,
      'analyte_key', v_item.analyte_key, 'sex', v_item.sex,
      'before', jsonb_build_object('low', v_item.low, 'high', v_item.high, 'unit', v_item.unit)));
end;
$$;

-- Physician approval makes the draft live and supersedes the previous live
-- set in one transaction, then refreshes the clinic's roster flags.
create function public.approve_range_set(p_set_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org uuid := public._portal_gate(array['physician']::public.app_role[]);
  v_set public.lab_range_sets;
  v_prev public.lab_range_sets;
  v_count int;
begin
  perform pg_advisory_xact_lock(hashtextextended('lab_range_sets:' || v_org::text, 0));
  select * into v_set from public.lab_range_sets where id = p_set_id and org_id = v_org for update;
  if v_set.id is null then
    raise exception 'range set not found' using errcode = 'P0002';
  end if;
  if v_set.status <> 'draft' then
    raise exception 'only a draft range set can be approved' using errcode = 'P0001';
  end if;
  select count(*) into v_count from public.lab_range_set_items where range_set_id = p_set_id;
  if v_count = 0 then
    raise exception 'an empty range set cannot be approved' using errcode = 'P0001';
  end if;

  update public.lab_range_sets set status = 'superseded', closed_at = now()
    where org_id = v_org and status = 'approved'
    returning * into v_prev;

  update public.lab_range_sets
    set status = 'approved', approved_by = auth.uid(), approved_at = now()
    where id = p_set_id;

  perform public.refresh_roster_summary(p.id) from public.patients p where p.org_id = v_org;

  perform public._audit_log_insert('range_set_approved', auth.uid(), null, v_org,
    jsonb_build_object('range_set_id', p_set_id, 'version', v_set.version,
      'item_count', v_count, 'superseded_version', v_prev.version));
end;
$$;

create function public.discard_range_set_draft(p_set_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org uuid := public._portal_gate(array['physician']::public.app_role[]);
  v_set public.lab_range_sets;
begin
  select * into v_set from public.lab_range_sets where id = p_set_id and org_id = v_org for update;
  if v_set.id is null then
    raise exception 'range set not found' using errcode = 'P0002';
  end if;
  if v_set.status <> 'draft' then
    raise exception 'only a draft range set can be discarded' using errcode = 'P0001';
  end if;
  update public.lab_range_sets set status = 'discarded', closed_at = now() where id = p_set_id;
  perform public._audit_log_insert('range_set_discarded', auth.uid(), null, v_org,
    jsonb_build_object('range_set_id', p_set_id, 'version', v_set.version));
end;
$$;

revoke all on function public.list_range_sets() from public, anon;
revoke all on function public.get_range_set_items(uuid) from public, anon;
revoke all on function public.create_range_set_draft(text) from public, anon;
revoke all on function public.upsert_range_set_item(uuid, text, text, text, numeric, numeric, text) from public, anon;
revoke all on function public.delete_range_set_item(uuid) from public, anon;
revoke all on function public.approve_range_set(uuid) from public, anon;
revoke all on function public.discard_range_set_draft(uuid) from public, anon;
grant execute on function public.list_range_sets() to authenticated;
grant execute on function public.get_range_set_items(uuid) to authenticated;
grant execute on function public.create_range_set_draft(text) to authenticated;
grant execute on function public.upsert_range_set_item(uuid, text, text, text, numeric, numeric, text) to authenticated;
grant execute on function public.delete_range_set_item(uuid) to authenticated;
grant execute on function public.approve_range_set(uuid) to authenticated;
grant execute on function public.discard_range_set_draft(uuid) to authenticated;

select public.refresh_roster_summary_all();
