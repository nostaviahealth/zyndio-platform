-- APP-05: the real lab pipeline (one server-side path).
--
-- The patient app uploads the file into the private lab-reports bucket and
-- files a lab_reports row (as before, TC-036), now with the file's SHA-256;
-- then the analyze-lab-report Edge Function extracts, maps, normalises and
-- files the results here in one transaction. Fictional data only in tests.
--
--   1. public.lab_analyte_loinc - the REVIEWED analyte -> LOINC table. The
--      pipeline maps a printed analyte name only through this table (exact
--      match on a normalised alias); anything else is stored as unmapped. Rows
--      change only by migration (reviewed in a PR), never from a client.
--   2. lab_reports: file_sha256 (dedupe: one report per file per patient),
--      extraction_status, collected_on, lab_name.
--   3. lab_results: the result as printed (name, value text, unit, printed
--      reference range), LOINC, the conversion used (kind + factor), per-field
--      confidence and needs-review reason codes. The canonical value stays in
--      `value` / `unit` (US units). `original_value` keeps its TC-015 meaning
--      (a staff correction), so the as-reported value has its own columns.
--   4. lab_pipeline_file_results() - service_role only: replaces a report's
--      results and updates the report atomically.
--
-- No client gets a new write path: lab_results stays server-written only
-- (TC-040 / pgTAP 746), and the new function is not on the TC-040 allowlist.

-- ---------------------------------------------------------------------------
-- 1. Reviewed analyte -> LOINC mapping
-- ---------------------------------------------------------------------------

create table public.lab_analyte_loinc (
  analyte_key text primary key check (analyte_key ~ '^[a-z0-9_]{1,40}$'),
  display_name text not null,
  loinc text not null unique check (loinc ~ '^[0-9]{1,7}-[0-9]$'),
  canonical_unit text not null,
  -- Printed names this analyte is known by. Compared after normalising both
  -- sides (lower case, accents and punctuation removed - labNormalize.ts
  -- analyteNameKey). An alias must not be shared by two analytes (trigger).
  aliases text[] not null default '{}',
  reviewed_by text not null,
  reviewed_on date not null,
  created_at timestamptz not null default now()
);

alter table public.lab_analyte_loinc enable row level security;
alter table public.lab_analyte_loinc force row level security;
revoke all on public.lab_analyte_loinc from public, anon, authenticated;
-- Reference data (no patient data): signed-in users may read it (e.g. the
-- physician portal labelling a LOINC). No client writes.
grant select on public.lab_analyte_loinc to authenticated;
create policy lab_analyte_loinc_read on public.lab_analyte_loinc
  for select to authenticated using (true);

-- Same normalisation as labNormalize.ts analyteNameKey() (accents are
-- removed there too; aliases here are ASCII).
create function public._lab_alias_key(p text)
returns text
language sql
immutable
set search_path = ''
as $$
  select btrim(regexp_replace(lower(p), '[^a-z0-9]+', ' ', 'g'));
$$;
revoke all on function public._lab_alias_key(text) from public, anon, authenticated;

create function public._lab_analyte_loinc_unique_aliases()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  clash text;
begin
  select public._lab_alias_key(a) into clash
    from public.lab_analyte_loinc o, unnest(o.aliases || o.analyte_key) a
   where o.analyte_key <> new.analyte_key
     and public._lab_alias_key(a) in (select public._lab_alias_key(x) from unnest(new.aliases || new.analyte_key) x)
   limit 1;
  if clash is not null then
    raise exception 'lab_analyte_loinc: alias "%" already maps to another analyte', clash
      using errcode = '23505';
  end if;
  return new;
end;
$$;
revoke all on function public._lab_analyte_loinc_unique_aliases() from public, anon, authenticated;

create trigger lab_analyte_loinc_unique_aliases
  before insert or update on public.lab_analyte_loinc
  for each row execute function public._lab_analyte_loinc_unique_aliases();

-- Starting codes (APP-05 brief, 4 Nov 2026). Lp(a) reported in nmol/L uses
-- its own LOINC (43583-4) - chosen by unit in labCatalog.ts loincByUnit, not
-- a separate row, because the printed names are the same.
-- Plain "LDL" / "LDL cholesterol" is deliberately NOT an alias: whether it is
-- calculated (13457-7) or direct (18262-6) can't be told from the name, so
-- it is stored unmapped for review rather than guessed.
-- Plain "Glucose" is not an alias of fasting glucose (1558-6) for the same
-- reason (2345-7 is non-fasting).
insert into public.lab_analyte_loinc (analyte_key, display_name, loinc, canonical_unit, aliases, reviewed_by, reviewed_on) values
  ('hba1c', 'HbA1c', '4548-4', '%', array['HbA1c', 'Hb A1c', 'Hemoglobin A1c', 'Haemoglobin A1c', 'Glycated hemoglobin', 'Glycated haemoglobin', 'Glycohemoglobin', 'A1c', 'HgbA1c', 'Hgb A1c'], 'APP-05 brief', '2026-11-04'),
  ('glucose_fasting', 'Fasting glucose', '1558-6', 'mg/dL', array['Glucose, fasting', 'Fasting glucose', 'Glucose (fasting)', 'Fasting plasma glucose', 'Glucose fasting', 'FPG'], 'APP-05 brief', '2026-11-04'),
  ('insulin_fasting', 'Fasting insulin', '20448-7', 'uIU/mL', array['Insulin', 'Insulin, fasting', 'Fasting insulin', 'Insulin (fasting)'], 'APP-05 brief', '2026-11-04'),
  ('triglycerides', 'Triglycerides', '2571-8', 'mg/dL', array['Triglycerides', 'Triglyceride', 'TG', 'Trigs'], 'APP-05 brief', '2026-11-04'),
  ('cholesterol_total', 'Total cholesterol', '2093-3', 'mg/dL', array['Total cholesterol', 'Cholesterol, total', 'Cholesterol total', 'Cholesterol'], 'APP-05 brief', '2026-11-04'),
  ('ldl_c_calc', 'LDL cholesterol (calculated)', '13457-7', 'mg/dL', array['LDL cholesterol, calculated', 'LDL cholesterol (calculated)', 'LDL-C calculated', 'LDL-C (calculated)', 'LDL calculated', 'LDL calc', 'LDL cholesterol calc', 'LDL chol calc'], 'APP-05 brief', '2026-11-04'),
  ('ldl_c_direct', 'LDL cholesterol (direct)', '18262-6', 'mg/dL', array['LDL cholesterol, direct', 'LDL cholesterol (direct)', 'LDL-C direct', 'LDL-C (direct)', 'Direct LDL', 'LDL direct'], 'APP-05 brief', '2026-11-04'),
  ('hdl_c', 'HDL cholesterol', '2085-9', 'mg/dL', array['HDL cholesterol', 'HDL-C', 'HDL', 'Cholesterol, HDL', 'HDL chol'], 'APP-05 brief', '2026-11-04'),
  ('non_hdl_c', 'Non-HDL cholesterol', '43396-1', 'mg/dL', array['Non-HDL cholesterol', 'Non-HDL-C', 'Non HDL', 'Cholesterol, non-HDL', 'Non-HDL'], 'APP-05 brief', '2026-11-04'),
  ('apob', 'ApoB', '1884-6', 'mg/dL', array['ApoB', 'Apo B', 'Apolipoprotein B', 'Apolipoprotein B-100', 'ApoB-100'], 'APP-05 brief', '2026-11-04'),
  ('lpa', 'Lp(a)', '10835-7', 'mg/dL', array['Lp(a)', 'Lipoprotein (a)', 'Lipoprotein(a)', 'Lipoprotein a', 'Lpa'], 'APP-05 brief', '2026-11-04'),
  ('hscrp', 'hsCRP', '30522-7', 'mg/L', array['hsCRP', 'hs-CRP', 'hs CRP', 'High sensitivity CRP', 'High-sensitivity C-reactive protein', 'C-reactive protein, high sensitivity', 'CRP, high sensitivity', 'Cardio CRP'], 'APP-05 brief', '2026-11-04'),
  ('alt', 'ALT', '1742-6', 'U/L', array['ALT', 'ALT (SGPT)', 'SGPT', 'Alanine aminotransferase', 'Alanine transaminase'], 'APP-05 brief', '2026-11-04'),
  ('ast', 'AST', '1920-8', 'U/L', array['AST', 'AST (SGOT)', 'SGOT', 'Aspartate aminotransferase', 'Aspartate transaminase'], 'APP-05 brief', '2026-11-04'),
  ('ggt', 'GGT', '2324-2', 'U/L', array['GGT', 'Gamma GT', 'Gamma-glutamyl transferase', 'Gamma glutamyltransferase', 'GGTP'], 'APP-05 brief', '2026-11-04'),
  ('creatinine', 'Creatinine', '2160-0', 'mg/dL', array['Creatinine', 'Creatinine, serum', 'Serum creatinine'], 'APP-05 brief', '2026-11-04'),
  ('egfr', 'eGFR', '98979-8', 'mL/min/1.73m2', array['eGFR', 'Estimated GFR', 'eGFR (CKD-EPI 2021)', 'eGFR CKD-EPI'], 'APP-05 brief', '2026-11-04'),
  ('tsh', 'TSH', '3016-3', 'mIU/L', array['TSH', 'Thyroid stimulating hormone', 'Thyrotropin'], 'APP-05 brief', '2026-11-04'),
  ('ft4', 'Free T4', '3024-7', 'ng/dL', array['Free T4', 'FT4', 'T4, free', 'Free thyroxine', 'Thyroxine, free'], 'APP-05 brief', '2026-11-04'),
  ('ft3', 'Free T3', '3051-0', 'pg/mL', array['Free T3', 'FT3', 'T3, free', 'Free triiodothyronine', 'Triiodothyronine, free'], 'APP-05 brief', '2026-11-04'),
  ('testosterone', 'Testosterone', '2986-8', 'ng/dL', array['Testosterone', 'Testosterone, total', 'Total testosterone'], 'APP-05 brief', '2026-11-04'),
  ('estradiol', 'Estradiol', '2243-4', 'pg/mL', array['Estradiol', 'Oestradiol', 'E2', 'Estradiol (E2)'], 'APP-05 brief', '2026-11-04'),
  ('shbg', 'SHBG', '13967-5', 'nmol/L', array['SHBG', 'Sex hormone binding globulin', 'Sex hormone-binding globulin'], 'APP-05 brief', '2026-11-04'),
  ('vitamin_d', 'Vitamin D (25-OH)', '62292-8', 'ng/mL', array['Vitamin D', 'Vitamin D, 25-hydroxy', '25-hydroxyvitamin D', '25-OH vitamin D', '25(OH)D', 'Vitamin D 25-OH', 'Vitamin D, 25-OH, total'], 'APP-05 brief', '2026-11-04'),
  ('ferritin', 'Ferritin', '2276-4', 'ng/mL', array['Ferritin', 'Ferritin, serum', 'Serum ferritin'], 'APP-05 brief', '2026-11-04'),
  ('igf1', 'IGF-1', '2484-4', 'ng/mL', array['IGF-1', 'IGF 1', 'IGF1', 'Insulin-like growth factor 1', 'Insulin-like growth factor I', 'Somatomedin C'], 'APP-05 brief', '2026-11-04');

-- ---------------------------------------------------------------------------
-- 2. lab_reports: dedupe + extraction outcome
-- ---------------------------------------------------------------------------

alter table public.lab_reports
  add column file_sha256 text check (file_sha256 is null or file_sha256 ~ '^[0-9a-f]{64}$'),
  add column extraction_status text not null default 'pending'
    check (extraction_status in ('pending', 'extracted', 'needs_review', 'identity_hold')),
  add column collected_on date,
  add column lab_name text check (lab_name is null or length(lab_name) <= 200);

-- One report per file per patient: the same file uploaded twice is refused
-- (23505), so its results are never filed or counted twice.
create unique index lab_reports_patient_file_sha256_key
  on public.lab_reports (patient_id, file_sha256) where file_sha256 is not null;

-- ---------------------------------------------------------------------------
-- 3. lab_results: as-reported values, LOINC, conversion, confidence
-- ---------------------------------------------------------------------------

alter table public.lab_results
  add column loinc text check (loinc is null or loinc ~ '^[0-9]{1,7}-[0-9]$'),
  add column reported_name text check (reported_name is null or length(reported_name) <= 200),
  add column reported_value text check (reported_value is null or length(reported_value) <= 64),
  add column reported_unit text check (reported_unit is null or length(reported_unit) <= 32),
  add column value_comparator text check (value_comparator is null or value_comparator in ('<', '<=', '>', '>=')),
  -- How `value` was derived from reported_value: none (same unit), multiply
  -- or divide by conversion_factor, or hba1c (mmol/mol / 10.929 + 2.15).
  add column conversion_kind text check (conversion_kind is null or conversion_kind in ('none', 'multiply', 'divide', 'hba1c')),
  add column conversion_factor numeric,
  add column reference_range_text text check (reference_range_text is null or length(reference_range_text) <= 64),
  add column field_confidence jsonb,
  add column confidence numeric check (confidence is null or (confidence >= 0 and confidence <= 1)),
  add column review_reasons text[] not null default '{}',
  -- A mapped result must name a reviewed analyte and its LOINC; an unmapped
  -- one has no LOINC.
  add constraint lab_results_loinc_mapped check (
    (is_unmapped and loinc is null) or not is_unmapped
  ),
  add constraint lab_results_conversion_factor check (
    (conversion_kind is null and conversion_factor is null)
    or (conversion_kind = 'none' and conversion_factor = 1)
    or (conversion_kind in ('multiply', 'divide', 'hba1c') and conversion_factor > 0)
  );

-- ---------------------------------------------------------------------------
-- 4. Filing a report's results (service_role only)
-- ---------------------------------------------------------------------------

-- Replaces every result of one report and updates the report, in one
-- transaction, so a re-analysis never leaves old and new results mixed and a
-- failure leaves the report as it was. org_id / patient_id / taken_at come
-- from the report row, never from the payload.
--
-- p_report: { file_sha256, extraction_status, identity_hold, collected_on,
--             lab_name, data }  (data is merged into lab_reports.data)
-- p_results: [ { analyte_key, analyte_label, loinc, is_unmapped, value,
--               value_comparator, unit, status, range_low, range_high,
--               reported_name, reported_value, reported_unit,
--               conversion_kind, conversion_factor, reference_range_text,
--               field_confidence, confidence, review_reasons } ]
create function public.lab_pipeline_file_results(p_report_id uuid, p_report jsonb, p_results jsonb)
returns integer
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare
  r public.lab_reports%rowtype;
  v_taken timestamptz;
  v_count integer;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'lab_pipeline_file_results: service_role only' using errcode = '42501';
  end if;
  if jsonb_typeof(p_results) is distinct from 'array' or jsonb_typeof(p_report) is distinct from 'object' then
    raise exception 'lab_pipeline_file_results: invalid payload' using errcode = '22023';
  end if;

  select * into r from public.lab_reports where id = p_report_id for update;
  if not found then
    raise exception 'lab_pipeline_file_results: no such report' using errcode = 'P0002';
  end if;

  update public.lab_reports
     set file_sha256 = coalesce(file_sha256, p_report ->> 'file_sha256'),
         extraction_status = p_report ->> 'extraction_status',
         -- The pipeline can set a hold but never clear one (a person does).
         identity_hold = identity_hold or coalesce((p_report ->> 'identity_hold')::boolean, false),
         collected_on = (p_report ->> 'collected_on')::date,
         lab_name = p_report ->> 'lab_name',
         data = data || coalesce(p_report -> 'data', '{}'::jsonb)
   where id = r.id;

  -- Results are dated by the collection date (noon UTC, so no time zone
  -- moves it to another day); no printed date -> the upload time.
  v_taken := coalesce(((p_report ->> 'collected_on')::date + time '12:00') at time zone 'UTC', r.created_at);

  delete from public.lab_results where lab_report_id = r.id;

  insert into public.lab_results (
    org_id, patient_id, lab_report_id, analyte_key, analyte_label, loinc, is_unmapped,
    value, value_comparator, unit, status, range_low, range_high, taken_at,
    reported_name, reported_value, reported_unit, conversion_kind, conversion_factor,
    reference_range_text, field_confidence, confidence, review_reasons)
  select r.org_id, r.patient_id, r.id, x.analyte_key, x.analyte_label, x.loinc, coalesce(x.is_unmapped, false),
         x.value, x.value_comparator, x.unit, x.status, x.range_low, x.range_high, v_taken,
         x.reported_name, x.reported_value, x.reported_unit, x.conversion_kind, x.conversion_factor,
         x.reference_range_text, x.field_confidence, x.confidence, coalesce(x.review_reasons, '{}')
    from jsonb_to_recordset(p_results) as x(
      analyte_key text, analyte_label text, loinc text, is_unmapped boolean,
      value numeric, value_comparator text, unit text, status text, range_low numeric, range_high numeric,
      reported_name text, reported_value text, reported_unit text, conversion_kind text, conversion_factor numeric,
      reference_range_text text, field_confidence jsonb, confidence numeric, review_reasons text[]);
  get diagnostics v_count = row_count;

  -- A mapped result must use the reviewed table's analyte and LOINC (or the
  -- Lp(a) molar code) - the function can't file a mapping nobody reviewed.
  if exists (
    select 1 from public.lab_results lr
     where lr.lab_report_id = r.id and not lr.is_unmapped
       and not exists (select 1 from public.lab_analyte_loinc m
                        where m.analyte_key = lr.analyte_key
                          and (m.loinc = lr.loinc or (m.analyte_key = 'lpa' and lr.loinc = '43583-4')))
  ) then
    raise exception 'lab_pipeline_file_results: result not in the reviewed LOINC table' using errcode = '23514';
  end if;

  return v_count;
end;
$$;

revoke all on function public.lab_pipeline_file_results(uuid, jsonb, jsonb) from public, anon, authenticated;
grant execute on function public.lab_pipeline_file_results(uuid, jsonb, jsonb) to service_role;
