-- PR #40 review: foreign keys that anonymize a deleted account (ON DELETE
-- SET NULL) or remove a deleted clinic (ON DELETE CASCADE) were rejected by
-- the freeze / append-only triggers. Those foreign keys are the deletion
-- lifecycle already declared on the columns.
--
-- A direct edit of an approved range or of billing history is still refused.
-- Clearing created_by / approved_by / changed_by is allowed only when that
-- user row is already gone, and no other column moves. Deleting a range set
-- or a history row is allowed only when its clinic row is already gone
-- (the cascade). There is no session flag and no trigger-depth bypass.
--
-- Periods for one clinic cannot overlap, including a service_role insert.
-- The timeline keyset cursor is (occurred_at, source, ref_id), not the
-- timestamp alone.

create or replace function public._enforce_lab_range_set_lifecycle()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_gone boolean;
begin
  if TG_OP = 'DELETE' then
    -- Clinic erasure: the organization row is already gone, so this is the
    -- declared ON DELETE CASCADE, not a direct delete of the approved set.
    if not exists (select 1 from public.organizations o where o.id = OLD.org_id) then
      return OLD;
    end if;
    raise exception 'range sets are never deleted' using errcode = '42501';
  end if;

  if NEW.org_id <> OLD.org_id or NEW.version <> OLD.version
     or NEW.created_at is distinct from OLD.created_at then
    raise exception 'range set org and version are immutable' using errcode = '42501';
  end if;
  if NEW.status <> OLD.status and not (
       (OLD.status = 'draft' and NEW.status in ('approved', 'discarded'))
       or (OLD.status = 'approved' and NEW.status = 'superseded')
     ) then
    raise exception 'range set cannot move from % to %', OLD.status, NEW.status using errcode = '42501';
  end if;

  if OLD.status <> 'draft' then
    if NEW.note is distinct from OLD.note
       or NEW.approved_at is distinct from OLD.approved_at then
      raise exception 'an approved range set is frozen' using errcode = '42501';
    end if;
    -- closed_at is stamped only when an approved set is superseded.
    if NEW.closed_at is distinct from OLD.closed_at
       and not (OLD.status = 'approved' and NEW.status = 'superseded' and NEW.closed_at is not null) then
      raise exception 'an approved range set is frozen' using errcode = '42501';
    end if;

    if NEW.created_by is distinct from OLD.created_by then
      select not exists (select 1 from auth.users u where u.id = OLD.created_by) into v_user_gone;
      if NEW.created_by is not null or OLD.created_by is null or not v_user_gone then
        raise exception 'an approved range set is frozen' using errcode = '42501';
      end if;
    end if;
    if NEW.approved_by is distinct from OLD.approved_by then
      select not exists (select 1 from auth.users u where u.id = OLD.approved_by) into v_user_gone;
      if NEW.approved_by is not null or OLD.approved_by is null or not v_user_gone then
        raise exception 'an approved range set is frozen' using errcode = '42501';
      end if;
    end if;
  end if;
  return NEW;
end;
$$;

create or replace function public._enforce_org_plan_history_append_only()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_close boolean;
  v_anonymize boolean;
  v_user_gone boolean;
begin
  if TG_OP = 'DELETE' then
    if not exists (select 1 from public.organizations o where o.id = OLD.org_id) then
      return OLD;
    end if;
    raise exception 'plan history is append-only' using errcode = '42501';
  end if;

  v_close := OLD.effective_to is null and NEW.effective_to is not null;
  v_anonymize := NEW.changed_by is distinct from OLD.changed_by;
  if v_anonymize then
    select not exists (select 1 from auth.users u where u.id = OLD.changed_by) into v_user_gone;
    v_anonymize := NEW.changed_by is null and OLD.changed_by is not null and v_user_gone;
    if NEW.changed_by is distinct from OLD.changed_by and not v_anonymize then
      raise exception 'plan history is append-only' using errcode = '42501';
    end if;
  end if;

  if (NEW.org_id, NEW.tier, NEW.standard_modules, NEW.effective_from, NEW.reason, NEW.created_at)
     is distinct from
     (OLD.org_id, OLD.tier, OLD.standard_modules, OLD.effective_from, OLD.reason, OLD.created_at) then
    raise exception 'plan history is append-only' using errcode = '42501';
  end if;
  if NEW.effective_to is distinct from OLD.effective_to and not v_close then
    raise exception 'plan history is append-only' using errcode = '42501';
  end if;
  if not v_close and NEW.changed_by is not distinct from OLD.changed_by
     and NEW.effective_to is not distinct from OLD.effective_to then
    return NEW;
  end if;
  return NEW;
end;
$$;

create or replace function public._enforce_org_plan_history_no_overlap()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if exists (
    select 1 from public.org_plan_history h
     where h.org_id = NEW.org_id
       and h.id is distinct from NEW.id
       and h.effective_from < coalesce(NEW.effective_to, 'infinity'::timestamptz)
       and NEW.effective_from < coalesce(h.effective_to, 'infinity'::timestamptz)
  ) then
    raise exception 'plan periods must not overlap' using errcode = '23514';
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_org_plan_history_no_overlap on public.org_plan_history;
create trigger trg_org_plan_history_no_overlap
  before insert or update on public.org_plan_history
  for each row execute function public._enforce_org_plan_history_no_overlap();

revoke all on function public._enforce_org_plan_history_no_overlap() from public, anon, authenticated;

-- Timeline keyset: same-timestamp events stay distinct via (source, ref_id).
drop function if exists public.patient_timeline(uuid, timestamptz, int);

create function public.patient_timeline(
  p_patient_id uuid,
  p_before timestamptz default null,
  p_limit int default 100,
  p_before_source text default null,
  p_before_ref uuid default null
)
returns setof public.timeline_event
language plpgsql
stable
security invoker
set search_path = pg_catalog, public
as $$
declare
  v_sql text;
begin
  if auth.uid() is null
     or not public.has_aal2()
     or coalesce(public.current_role()::text, '') not in ('physician', 'care_coordinator', 'read_only')
     or not exists (
       select 1 from public.patients p
        where p.id = p_patient_id and p.org_id = public.current_org_id()
     ) then
    return;
  end if;

  select string_agg(format('select * from %I.%I($1)', n.nspname, pr.proname), ' union all ' order by s.source_key)
    into v_sql
    from public.timeline_sources s
    join pg_proc pr on pr.oid = s.fn
    join pg_namespace n on n.oid = pr.pronamespace
   where s.enabled;

  if v_sql is null then
    return;
  end if;

  return query execute
    'select * from (' || v_sql || ') e'
    || ' where e.occurred_at is not null and ('
    || '   $2 is null'
    || '   or e.occurred_at < $2'
    || '   or (e.occurred_at = $2 and $3 is not null and (e.source, e.ref_id) > ($3, $4))'
    || ' )'
    || ' order by e.occurred_at desc, e.source, e.ref_id'
    || ' limit $5'
    using p_patient_id, p_before, p_before_source, p_before_ref,
          least(greatest(coalesce(p_limit, 100), 1), 500);
end;
$$;

revoke all on function public.patient_timeline(uuid, timestamptz, int, text, uuid) from public, anon;
grant execute on function public.patient_timeline(uuid, timestamptz, int, text, uuid) to authenticated;
