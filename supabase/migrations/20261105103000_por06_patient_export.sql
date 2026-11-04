-- POR-06: per-patient export (JSON and CSV).
--
-- export_patient_record(patient, format) returns the patient's record as one
-- whitelisted jsonb document; the portal serialises it to a .json file or a
-- flat .csv (lib/patientExport.ts). The server does the gate and the audit,
-- so the format the clinician chose is in the audit row either way.
--
--   * physician / care_coordinator only. read_only is refused with 42501
--     (an explicit block, not the not-found contract: read_only can see the
--     patient, it just may not take the data out). org_admin likewise.
--   * other clinic / unknown id -> null, no audit row (not-found contract).
--   * identity-held reports are excluded (they may be someone else's data).
--   * treatment is explicit columns only - never a dose.
--   * one 'patient_record_exported' audit row per export: actor, patient,
--     clinic, format and row counts.
-- Tests: supabase/tests/773_por06_patient_export.sql.

create function public.export_patient_record(p_patient_id uuid, p_format text)
returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare
  v_org uuid := public.current_org_id();
  v_format text := lower(btrim(coalesce(p_format, '')));
  v_patient public.patients;
  v_meta public.patient_roster_meta;
  v_labs jsonb;
  v_treatments jsonb;
  v_visits jsonb;
begin
  if auth.uid() is null
     or not public.has_aal2()
     or coalesce(public.current_role()::text, '') not in ('physician', 'care_coordinator') then
    raise exception 'not authorized to export patient records' using errcode = '42501';
  end if;
  if v_format not in ('json', 'csv') then
    raise exception 'format must be json or csv' using errcode = '22023';
  end if;

  select * into v_patient from public.patients where id = p_patient_id and org_id = v_org;
  if v_patient.id is null then
    return null;
  end if;
  select * into v_meta from public.patient_roster_meta where patient_id = p_patient_id and org_id = v_org;

  select coalesce(jsonb_agg(jsonb_build_object(
      'taken_at', r.taken_at,
      'analyte_key', r.analyte_key,
      'analyte_label', r.analyte_label,
      'value', r.value,
      'original_value', r.original_value,
      'unit', r.unit,
      'status', r.status,
      'range_low', r.range_low,
      'range_high', r.range_high,
      'range_source', r.range_source,
      'range_set_version', r.range_set_version,
      'lab_report_id', r.lab_report_id
    ) order by r.taken_at, r.analyte_key, r.id), '[]'::jsonb)
    into v_labs
    from public.patient_lab_rows(p_patient_id) r;

  select coalesce(jsonb_agg(jsonb_build_object(
      'name', t.name, 'started_on', t.started_on, 'status', t.status, 'source', t.source
    ) order by t.started_on nulls last, t.created_at), '[]'::jsonb)
    into v_treatments
    from public.patient_treatments t
    where t.patient_id = p_patient_id and t.org_id = v_org;

  select coalesce(jsonb_agg(jsonb_build_object('visit_on', v.visit_on) order by v.visit_on), '[]'::jsonb)
    into v_visits
    from public.patient_visits v
    where v.patient_id = p_patient_id and v.org_id = v_org;

  perform public.write_audit_log('patient_record_exported', auth.uid(), p_patient_id, v_org,
    jsonb_build_object(
      'format', v_format,
      'lab_result_count', jsonb_array_length(v_labs),
      'treatment_count', jsonb_array_length(v_treatments),
      'visit_count', jsonb_array_length(v_visits)));

  return jsonb_build_object(
    'schema_version', 1,
    'exported_at', now(),
    'format', v_format,
    'patient', jsonb_build_object(
      'patient_id', v_patient.id,
      'display_name', v_patient.display_name,
      'mrn', v_patient.mrn,
      'sex', v_meta.sex,
      'birth_date', v_meta.birth_date,
      'program_started_on', v_meta.program_started_on
    ),
    'treatments', v_treatments,
    'visits', v_visits,
    'lab_results', v_labs
  );
end;
$$;

revoke all on function public.export_patient_record(uuid, text) from public, anon;
grant execute on function public.export_patient_record(uuid, text) to authenticated;
