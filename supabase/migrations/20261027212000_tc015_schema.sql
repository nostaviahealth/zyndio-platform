-- TC-015 slice 1 (physician list + detail): clinical schema the roster/detail
-- read model needs. This slice is VIEW-ONLY for staff - every new table is
-- read through RLS/RPCs; no INSERT/UPDATE/DELETE path is granted to
-- authenticated (seed + lab pipeline write via the service role elsewhere).
--
--   * lab_reports.identity_hold  - a report flagged as possibly-not-this-patient
--     (POR: identity hold). Its results never reach trends or the latest-results
--     list until the patient resolves it in the app (slice-1 needs only the flag).
--   * public.lab_results         - value-level time series (the trend source):
--     one row per analyte measurement, org_id on every row, forced RLS.
--   * public.patient_treatments  - POR-07 treatment context, stored in explicit
--     columns (name/started_on/status/source) with NO dose column, so the store
--     structurally cannot carry a dose.
--   * public.patient_roster_meta - roster demographics + activity (age/sex via
--     birth_date, program start, last activity, open-question count) kept out of
--     the clinical value rows.

-- ---------------------------------------------------------------------------
-- lab_reports: identity-hold flag
-- ---------------------------------------------------------------------------

alter table public.lab_reports
  add column identity_hold boolean not null default false;

-- ---------------------------------------------------------------------------
-- lab_results: value-level time series
-- ---------------------------------------------------------------------------

create table public.lab_results (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  patient_id uuid not null references public.patients (id) on delete cascade,
  lab_report_id uuid not null references public.lab_reports (id) on delete cascade,
  analyte_key text not null,
  analyte_label text not null,
  value numeric,
  -- non-null => this value was corrected and the UI shows "was <original_value>".
  -- Corrections supersede but never delete the original (POR correction rule).
  original_value numeric,
  unit text,
  status text not null default 'within_range'
    check (status in ('within_range', 'outside_range', 'needs_review', 'baseline', 'no_range')),
  -- an analyte with no mapped reference range (e.g. Lp-PLA2) - "Not used in trends".
  is_unmapped boolean not null default false,
  -- null range => "No range set yet" and no band on the chart.
  range_low numeric,
  range_high numeric,
  taken_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

-- Trend/latest queries filter by (patient_id, analyte_key) and order by taken_at.
create index lab_results_patient_analyte_taken_idx
  on public.lab_results (patient_id, analyte_key, taken_at);
create index lab_results_org_id_idx on public.lab_results (org_id);
create index lab_results_lab_report_id_idx on public.lab_results (lab_report_id);

-- ---------------------------------------------------------------------------
-- patient_treatments: POR-07 treatment context - explicit columns, no dose.
-- ---------------------------------------------------------------------------

create table public.patient_treatments (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  patient_id uuid not null references public.patients (id) on delete cascade,
  name text not null,
  started_on date,
  status text,
  source text,
  created_at timestamptz not null default now()
);

create index patient_treatments_patient_id_idx on public.patient_treatments (patient_id);
create index patient_treatments_org_id_idx on public.patient_treatments (org_id);

-- ---------------------------------------------------------------------------
-- patient_roster_meta: roster demographics + activity (one row per patient).
-- ---------------------------------------------------------------------------

create table public.patient_roster_meta (
  patient_id uuid primary key references public.patients (id) on delete cascade,
  org_id uuid not null references public.organizations (id) on delete cascade,
  sex text,
  birth_date date,
  program_started_on date,
  last_activity_at timestamptz,
  open_questions int not null default 0
);

create index patient_roster_meta_org_id_idx on public.patient_roster_meta (org_id);

-- ---------------------------------------------------------------------------
-- Enable + force RLS on the new tables. Policies land in the next migration.
-- View-only slice: strip the INSERT/UPDATE/DELETE table grants so no client
-- role can write regardless of policy (seed + pipeline use the service role).
-- ---------------------------------------------------------------------------

alter table public.lab_results enable row level security;
alter table public.lab_results force row level security;
alter table public.patient_treatments enable row level security;
alter table public.patient_treatments force row level security;
alter table public.patient_roster_meta enable row level security;
alter table public.patient_roster_meta force row level security;

revoke insert, update, delete on public.lab_results from anon, authenticated;
revoke insert, update, delete on public.patient_treatments from anon, authenticated;
revoke insert, update, delete on public.patient_roster_meta from anon, authenticated;
