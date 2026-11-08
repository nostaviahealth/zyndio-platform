-- POR-04: pre-visit brief.
--
--   * public.patient_visits - the visit dates a brief is measured from.
--     Recorded by physician / care_coordinator through record_patient_visit()
--     (audited); read like the rest of the clinical record.
--   * patient_previsit_brief(patient) - STRUCTURED facts only (numbers,
--     dates, marker keys, fixed codes). The portal renders them with fixed
--     template wording (lib/previsitBrief.ts); there is no free text and no
--     AI text anywhere in the payload. Sections:
--       since          - last visit, else program start, else first result
--       out_of_range   - latest result per marker that is outside its
--                        effective (approved-set) range
--       changes        - per marker: baseline (first trend-eligible result)
--                        vs latest, same unit only
--       flags          - needs review, identity hold, open questions
--       missing        - fixed codes: no_labs, no_labs_since_visit,
--                        labs_stale (> 90 days), marker_not_rechecked,
--                        no_treatment
--     Viewing a brief is audited like a detail open.
--   * Visits also become a timeline source ('visits').
-- Tests: supabase/tests/772_por04_previsit_brief.sql.

create table public.patient_visits (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  patient_id uuid not null references public.patients (id) on delete cascade,
  visit_on date not null check (visit_on >= date '2000-01-01'),
  recorded_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create index patient_visits_patient_idx on public.patient_visits (patient_id, visit_on desc);
create index patient_visits_org_id_idx on public.patient_visits (org_id);

alter table public.patient_visits enable row level security;
alter table public.patient_visits force row level security;
revoke insert, update, delete on public.patient_visits from anon, authenticated;

create policy patient_visits_staff_select on public.patient_visits
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator', 'read_only')
  );

create function public.record_patient_visit(p_patient_id uuid, p_visit_on date default null)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org uuid := public._portal_gate(array['physician', 'care_coordinator']::public.app_role[]);
  v_on date := coalesce(p_visit_on, current_date);
  v_id uuid;
begin
  if not exists (select 1 from public.patients where id = p_patient_id and org_id = v_org) then
    raise exception 'patient not found' using errcode = 'P0002';
  end if;
  if v_on > current_date + 1 then
    raise exception 'a visit cannot be in the future' using errcode = '22023';
  end if;
  insert into public.patient_visits (org_id, patient_id, visit_on, recorded_by)
  values (v_org, p_patient_id, v_on, auth.uid())
  returning id into v_id;
  perform public._audit_log_insert('patient_visit_recorded', auth.uid(), p_patient_id, v_org,
    jsonb_build_object('visit_id', v_id, 'visit_on', v_on));
  return v_id;
end;
$$;

revoke all on function public.record_patient_visit(uuid, date) from public, anon;
grant execute on function public.record_patient_visit(uuid, date) to authenticated;

-- ---------------------------------------------------------------------------
-- Timeline source: visits.
-- ---------------------------------------------------------------------------

create function public.timeline_source_visits(p_patient_id uuid)
returns setof public.timeline_event
language sql
stable
security invoker
set search_path = pg_catalog, public
as $$
  select v.visit_on::timestamptz, 'visits', 'visit', 'Visit', null::text, v.id,
         jsonb_build_object('visit_on', v.visit_on)
  from public.patient_visits v
  where v.patient_id = p_patient_id;
$$;

grant execute on function public.timeline_source_visits(uuid) to authenticated;
insert into public.timeline_sources (source_key, fn, label)
values ('visits', 'public.timeline_source_visits(uuid)', 'Visits');

-- ---------------------------------------------------------------------------
-- patient_lab_rows(patient): every lab value the caller may see for the
-- patient (RLS, own clinic), identity-held reports excluded, with the
-- effective (approved-set) range and status. Shared by the brief and export.
-- ---------------------------------------------------------------------------

create function public.patient_lab_rows(p_patient_id uuid)
returns table (
  id uuid,
  lab_report_id uuid,
  analyte_key text,
  analyte_label text,
  value numeric,
  original_value numeric,
  unit text,
  status text,
  is_unmapped boolean,
  range_low numeric,
  range_high numeric,
  range_source text,
  range_set_version int,
  taken_at timestamptz
)
language sql
stable
security invoker
set search_path = pg_catalog, public
as $$
  select lr.id, lr.lab_report_id, lr.analyte_key, lr.analyte_label, lr.value, lr.original_value, lr.unit,
    public.lab_effective_status(lr.status, lr.is_unmapped, lr.value, er.range_set_version is not null, er.range_low, er.range_high),
    lr.is_unmapped,
    case when er.range_set_version is not null then er.range_low else lr.range_low end,
    case when er.range_set_version is not null then er.range_high else lr.range_high end,
    case when er.range_set_version is not null then 'approved'
         when lr.range_low is not null or lr.range_high is not null then 'default' else 'none' end,
    er.range_set_version,
    lr.taken_at
  from public.lab_results lr
  left join lateral public.lab_effective_range(lr.org_id, p_patient_id, lr.analyte_key, lr.unit) er on true
  where lr.patient_id = p_patient_id
    and not public.lab_report_held(lr.lab_report_id);
$$;

revoke all on function public.patient_lab_rows(uuid) from public, anon;
grant execute on function public.patient_lab_rows(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- The brief.
-- ---------------------------------------------------------------------------

create function public.patient_previsit_brief(p_patient_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare
  v_org uuid := public.current_org_id();
  v_meta public.patient_roster_meta;
  v_treatment public.patient_treatments;
  v_last_visit date;
  v_first_result timestamptz;
  v_latest_result timestamptz;
  v_since timestamptz;
  v_basis text;
  v_result jsonb;
begin
  -- Same gate and not-found contract as open_patient_detail.
  if auth.uid() is null
     or not public.has_aal2()
     or coalesce(public.current_role()::text, '') not in ('physician', 'care_coordinator', 'read_only') then
    return null;
  end if;
  if not exists (select 1 from public.patients where id = p_patient_id and org_id = v_org) then
    return null;
  end if;

  select * into v_meta from public.patient_roster_meta where patient_id = p_patient_id and org_id = v_org;
  select * into v_treatment from public.patient_treatments
    where patient_id = p_patient_id and org_id = v_org
    order by started_on desc nulls last, created_at desc limit 1;
  select max(visit_on) into v_last_visit from public.patient_visits
    where patient_id = p_patient_id and org_id = v_org and visit_on <= current_date;

  select min(taken_at), max(taken_at) into v_first_result, v_latest_result from public.patient_lab_rows(p_patient_id);

  if v_last_visit is not null then
    v_since := v_last_visit::timestamptz; v_basis := 'last_visit';
  elsif v_meta.program_started_on is not null then
    v_since := v_meta.program_started_on::timestamptz; v_basis := 'program_start';
  elsif v_first_result is not null then
    v_since := v_first_result; v_basis := 'first_result';
  else
    v_since := null; v_basis := 'none';
  end if;

  v_result := jsonb_build_object(
    'patient_id', p_patient_id,
    'generated_at', now(),
    'since', jsonb_build_object('date', v_since, 'basis', v_basis),
    'last_visit_on', v_last_visit,
    'treatment', case when v_treatment.id is not null then
      jsonb_build_object('name', v_treatment.name, 'status', v_treatment.status, 'started_on', v_treatment.started_on)
      else null end,
    'counts', jsonb_build_object(
      'results_since', (select count(*) from public.patient_lab_rows(p_patient_id) where v_since is null or taken_at >= v_since),
      'markers_since', (select count(distinct analyte_key) from public.patient_lab_rows(p_patient_id) where v_since is null or taken_at >= v_since)
    ),
    'out_of_range', coalesce((
      select jsonb_agg(jsonb_build_object(
        'analyte_key', l.analyte_key, 'analyte_label', l.analyte_label, 'value', l.value, 'unit', l.unit,
        'taken_at', l.taken_at, 'range_low', l.range_low, 'range_high', l.range_high,
        'range_source', l.range_source) order by l.analyte_label)
      from (
        select distinct on (analyte_key) *
        from public.patient_lab_rows(p_patient_id)
        where original_value is null
        order by analyte_key, taken_at desc, id desc
      ) l
      where l.status = 'outside_range'), '[]'::jsonb),
    'changes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'analyte_key', b.analyte_key, 'analyte_label', b.analyte_label, 'unit', b.unit,
        'baseline_value', b.value, 'baseline_at', b.taken_at,
        'latest_value', l.value, 'latest_at', l.taken_at,
        'delta', l.value - b.value, 'latest_status', l.status) order by b.analyte_label)
      from (
        select distinct on (analyte_key) * from public.patient_lab_rows(p_patient_id)
        where status <> 'needs_review' and not is_unmapped and value is not null
        order by analyte_key, taken_at asc, id asc
      ) b
      join (
        select distinct on (analyte_key) * from public.patient_lab_rows(p_patient_id)
        where status <> 'needs_review' and not is_unmapped and value is not null
        order by analyte_key, taken_at desc, id desc
      ) l on l.analyte_key = b.analyte_key
      where l.id <> b.id
        and lower(btrim(coalesce(l.unit, ''))) = lower(btrim(coalesce(b.unit, '')))), '[]'::jsonb),
    'flags', jsonb_build_object(
      'needs_review', (select count(*) from (
          select distinct on (analyte_key) status from public.patient_lab_rows(p_patient_id)
          where original_value is null order by analyte_key, taken_at desc, id desc) x
        where x.status = 'needs_review'),
      'identity_hold', exists (
        select 1 from public.lab_results lr
        where lr.patient_id = p_patient_id and lr.org_id = v_org and public.lab_report_held(lr.lab_report_id)),
      'open_questions', coalesce(v_meta.open_questions, 0)
    ),
    'missing', coalesce((
      select jsonb_agg(m.item order by m.ord)
      from (
        select 1 as ord, jsonb_build_object('code', 'no_labs') as item
          where v_first_result is null
        union all
        select 2, jsonb_build_object('code', 'no_labs_since_visit', 'since', v_since)
          where v_basis = 'last_visit' and v_first_result is not null and v_latest_result < v_since
        union all
        select 3, jsonb_build_object('code', 'labs_stale', 'latest_at', v_latest_result,
                    'days', extract(day from now() - v_latest_result)::int)
          where v_latest_result is not null and v_latest_result < now() - interval '90 days'
        union all
        select 4, jsonb_build_object('code', 'marker_not_rechecked', 'analyte_key', r.analyte_key,
                    'analyte_label', r.analyte_label, 'last_at', r.last_at)
          from (
            select analyte_key, max(analyte_label) as analyte_label, max(taken_at) as last_at
            from public.patient_lab_rows(p_patient_id)
            where not is_unmapped
            group by analyte_key
          ) r
          where v_basis = 'last_visit' and r.last_at < v_since
        union all
        select 5, jsonb_build_object('code', 'no_treatment')
          where v_treatment.id is null
      ) m), '[]'::jsonb)
  );

  perform public.write_audit_log('previsit_brief_viewed', auth.uid(), p_patient_id, v_org, '{}'::jsonb);
  return v_result;
end;
$$;

revoke all on function public.patient_previsit_brief(uuid) from public, anon;
grant execute on function public.patient_previsit_brief(uuid) to authenticated;
