-- APP-07: wearable data the patient app uploads from Apple Health / Health
-- Connect, one value per metric per local day per source.
--
-- The app aggregates on the device (never raw samples): for each metric and
-- each local calendar day it computes one value PER SOURCE (sources are never
-- added together) and marks exactly one source as `selected` - the source the
-- app's source policy prefers for that metric. Sleep is one value per night,
-- filed under the date the patient woke up.
--
-- Readers (physician timeline, zyndio.com integration summary) should read
-- public.wearable_daily_selected: one row per patient + date + metric. The
-- base table keeps the other sources' values too, so a later change of
-- preferred source never needs a client DELETE.
--
-- Uniqueness: (patient_id, metric_date, metric, source_app). The app upserts
-- on exactly that key, so a repeat upload replaces the value instead of adding
-- a second row (never double counts).
--
-- Who can reach a row (all policies `to authenticated`; anon has nothing):
--   * the patient: read, insert and update their OWN rows, with the same
--     email-confirmed + linked gates as lab_reports_self_* (TC-012), and only
--     with their own clinic as org_id. No delete.
--   * clinic staff: physician and care_coordinator read rows of their own
--     clinic's patients (aal2). read_only gets nothing (Leo R1: no clinical
--     detail for read_only, same as lab_results); org_admin gets nothing
--     ("admins manage users only").
--   * service_role bypasses RLS, as everywhere.
-- patient_id / org_id are immutable for client updates (TC-040 trigger).
-- Fictional data only in tests; no data changes here.

create table public.wearable_daily (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  patient_id uuid not null references public.patients (id) on delete cascade,
  -- The patient's LOCAL calendar day (device time zone). Sleep: the wake date.
  metric_date date not null,
  metric text not null,
  value numeric not null,
  unit text not null,
  -- Bundle id (iOS) / package name (Android) of the app that recorded the
  -- data, e.g. com.apple.health.<uuid>, com.sec.android.app.shealth. Never
  -- the device's display name (that often carries the patient's name).
  source_app text not null check (char_length(source_app) between 1 and 200),
  -- Coarse device class only: watch, phone, ring, scale (scales and other
  -- body-measurement devices such as BP cuffs), other.
  source_device text check (source_device in ('watch', 'phone', 'ring', 'scale', 'other')),
  -- Fraction (0..1) of the day's 24 clock hours that hold at least one sample
  -- from this source. Set for summed metrics (steps, exercise_minutes,
  -- active_energy_kcal); null for spot readings and sleep.
  coverage numeric(4, 3) check (coverage between 0 and 1),
  -- The one source the app chose for this patient + date + metric.
  selected boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint wearable_daily_patient_date_metric_source_key
    unique (patient_id, metric_date, metric, source_app),

  -- Metric list and canonical unit per metric. HRV SDNN (Apple) and RMSSD
  -- (Health Connect) are different measures and stay separate metrics.
  constraint wearable_daily_metric_unit check (
    (metric, unit) in (
      ('steps', 'count'),
      ('exercise_minutes', 'min'),
      ('active_energy_kcal', 'kcal'),
      ('resting_hr', 'bpm'),
      ('hrv_sdnn', 'ms'),
      ('hrv_rmssd', 'ms'),
      ('sleep_minutes', 'min'),
      ('weight_kg', 'kg'),
      ('bmi', 'kg/m2'),
      ('bp_systolic', 'mmHg'),
      ('bp_diastolic', 'mmHg'),
      ('vo2max', 'mL/kg/min'),
      ('spo2', '%')
    )
  ),

  -- Physiological plausibility: a value outside these limits is a unit or
  -- device error, not a reading, and is refused.
  constraint wearable_daily_value_plausible check (
    case metric
      when 'steps' then value between 0 and 200000
      when 'exercise_minutes' then value between 0 and 1440
      when 'active_energy_kcal' then value between 0 and 20000
      when 'resting_hr' then value between 20 and 250
      when 'hrv_sdnn' then value between 1 and 500
      when 'hrv_rmssd' then value between 1 and 500
      when 'sleep_minutes' then value between 0 and 1440
      when 'weight_kg' then value between 20 and 500
      when 'bmi' then value between 8 and 150
      when 'bp_systolic' then value between 50 and 300
      when 'bp_diastolic' then value between 20 and 200
      when 'vo2max' then value between 5 and 100
      when 'spo2' then value between 50 and 100
      else false
    end
  ),

  constraint wearable_daily_metric_date_floor check (metric_date >= date '2000-01-01')
);

-- Timeline / summary reads: one patient, one metric, a date range.
create index wearable_daily_patient_metric_date_idx
  on public.wearable_daily (patient_id, metric, metric_date);
create index wearable_daily_org_id_idx on public.wearable_daily (org_id);

comment on table public.wearable_daily is
  'APP-07: one on-device daily aggregate per patient + local date + metric + source app. '
  'Read wearable_daily_selected for one value per patient + date + metric.';

-- ---------------------------------------------------------------------------
-- Server-owned columns: updated_at is set here (clients have no UPDATE grant
-- on it), and a date in the future is refused (a device clock error).
-- ---------------------------------------------------------------------------
create function public._wearable_daily_before_write()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if new.metric_date > (now() at time zone 'utc')::date + 1 then
    raise exception 'wearable_daily: metric_date is in the future'
      using errcode = '22023';
  end if;
  new.updated_at := now();
  if tg_op = 'INSERT' then
    new.created_at := now();
  else
    new.created_at := old.created_at;
  end if;
  return new;
end;
$$;
revoke all on function public._wearable_daily_before_write() from public, anon, authenticated;

create trigger wearable_daily_before_write
  before insert or update on public.wearable_daily
  for each row execute function public._wearable_daily_before_write();

-- TC-040: patient_id / org_id can't be changed by a client once written.
create trigger wearable_daily_patient_clinic_immutable
  before update of patient_id, org_id on public.wearable_daily
  for each row execute function public._enforce_patient_and_clinic_immutable();

-- ---------------------------------------------------------------------------
-- Grants. anon: nothing. authenticated: SELECT, and INSERT/UPDATE only on the
-- columns the app sends (an upsert updates every column in its payload), so
-- id / created_at / updated_at stay server-owned. No DELETE / TRUNCATE.
-- ---------------------------------------------------------------------------
revoke all on public.wearable_daily from public, anon, authenticated;
grant select on public.wearable_daily to authenticated;
grant insert (org_id, patient_id, metric_date, metric, value, unit, source_app, source_device, coverage, selected)
  on public.wearable_daily to authenticated;
grant update (org_id, patient_id, metric_date, metric, value, unit, source_app, source_device, coverage, selected)
  on public.wearable_daily to authenticated;
grant all on public.wearable_daily to service_role;

alter table public.wearable_daily enable row level security;
alter table public.wearable_daily force row level security;

-- ---------------------------------------------------------------------------
-- Policies
-- ---------------------------------------------------------------------------
create policy wearable_daily_self_select on public.wearable_daily
  for select to authenticated
  using (
    patient_id = auth.uid()
    and public.current_email_confirmed()
    and public.current_patient_linked()
  );

create policy wearable_daily_self_insert on public.wearable_daily
  for insert to authenticated
  with check (
    patient_id = auth.uid()
    and public.current_email_confirmed()
    and public.current_patient_linked()
    and org_id = (select org_id from public.patients where id = auth.uid())
  );

create policy wearable_daily_self_update on public.wearable_daily
  for update to authenticated
  using (
    patient_id = auth.uid()
    and public.current_email_confirmed()
    and public.current_patient_linked()
  )
  with check (
    patient_id = auth.uid()
    and org_id = (select org_id from public.patients where id = auth.uid())
  );

-- The patient's clinic is checked explicitly (as in TC-040), not only the
-- row's org_id, so a row can never be read by a clinic the patient isn't in.
create policy wearable_daily_staff_select on public.wearable_daily
  for select to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator')
    and exists (select 1 from public.patients p
                 where p.id = wearable_daily.patient_id
                   and p.org_id = public.current_org_id())
  );

-- ---------------------------------------------------------------------------
-- wearable_daily_selected: one row per patient + date + metric - the selected
-- source's value. If two rows are ever marked selected (a source the app no
-- longer sees keeps its old flag), the most recently uploaded one wins.
-- security_invoker: the caller's wearable_daily RLS applies unchanged.
-- ---------------------------------------------------------------------------
create view public.wearable_daily_selected
with (security_invoker = true) as
  select distinct on (w.patient_id, w.metric_date, w.metric)
    w.id, w.org_id, w.patient_id, w.metric_date, w.metric, w.value, w.unit,
    w.source_app, w.source_device, w.coverage, w.updated_at
  from public.wearable_daily w
  where w.selected
  order by w.patient_id, w.metric_date, w.metric, w.updated_at desc, w.source_app;

revoke all on public.wearable_daily_selected from public, anon, authenticated;
grant select on public.wearable_daily_selected to authenticated, service_role;

comment on view public.wearable_daily_selected is
  'APP-07: one wearable value per patient + local date + metric (the app-selected source). '
  'RLS of wearable_daily applies (security_invoker).';
