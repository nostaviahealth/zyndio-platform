// TC-015 slice 1 fail-first integration: the physician roster + detail RPCs
// through PostgREST with real aal2 JWTs. Proves the server-enforced access
// rules a UI can't be trusted to apply:
//   - another clinic's patient returns the SAME not-found response as an
//     unknown id (never a distinct "forbidden"),
//   - each open_patient_detail call writes exactly one audit row,
//   - no `dose` key appears in any response payload.
//
// Expect FAIL until the schema + RLS + RPCs land (the rpc endpoints 404 /
// patients-with-lab-data can't be seeded).
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { integrationEnvReady, SUPABASE_URL, SUPABASE_ANON_KEY } from './setup';
import {
  createOrgAndMember,
  createUser,
  deleteUser,
  enrollAndVerifyTotp,
  restAdmin,
  signIn,
} from './helpers';

function rpc(name: string, token: string, body: unknown) {
  return fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: SUPABASE_ANON_KEY!,
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(body),
  });
}

async function aal2For(email: string, password: string) {
  const aal1 = await signIn(email, password);
  const { aal2Token } = await enrollAndVerifyTotp(aal1.access_token!);
  return aal2Token!;
}

describe.skipIf(!integrationEnvReady)('physician roster + detail RPCs', () => {
  const cleanupUserIds: string[] = [];
  let physician: Awaited<ReturnType<typeof createOrgAndMember>>;
  let physicianToken: string;
  let otherPhysician: Awaited<ReturnType<typeof createOrgAndMember>>;
  let otherPhysicianToken: string;
  let patientId: string;
  const unknownId = '00000000-0000-0000-0000-0000009e9e9e';

  beforeAll(async () => {
    physician = await createOrgAndMember('physician');
    cleanupUserIds.push(physician.userId);
    physicianToken = await aal2For(physician.email, physician.password);

    // A patient in the physician's org, with a lab report + results, a
    // treatment (no dose), and roster meta - all seeded via the service role.
    const patient = await createUser('tc015-patient');
    patientId = patient.userId;
    cleanupUserIds.push(patientId);
    await restAdmin('patients', {
      method: 'POST',
      body: JSON.stringify({ id: patientId, org_id: physician.orgId, display_name: 'Fictional Jordan Rivera', mrn: 'ZP-19001' }),
    });

    const reportRes = await restAdmin('lab_reports', {
      method: 'POST',
      body: JSON.stringify({ org_id: physician.orgId, patient_id: patientId, report_type: 'metabolic_panel', identity_hold: false }),
    });
    const [report] = (await reportRes.json()) as { id: string }[];

    await restAdmin('lab_results', {
      method: 'POST',
      body: JSON.stringify([
        { org_id: physician.orgId, patient_id: patientId, lab_report_id: report.id, analyte_key: 'hba1c', analyte_label: 'HbA1c', value: 5.5, unit: '%', status: 'within_range', taken_at: new Date(Date.now() - 20 * 86400000).toISOString() },
        { org_id: physician.orgId, patient_id: patientId, lab_report_id: report.id, analyte_key: 'hba1c', analyte_label: 'HbA1c', value: 5.7, unit: '%', status: 'within_range', taken_at: new Date(Date.now() - 80 * 86400000).toISOString() },
      ]),
    });
    await restAdmin('patient_treatments', {
      method: 'POST',
      body: JSON.stringify({ org_id: physician.orgId, patient_id: patientId, name: 'Example GLP-1 medication (fictional)', started_on: '2026-04-02', status: 'Active', source: 'Zyndio record, Oct 20, 2026' }),
    });
    await restAdmin('patient_roster_meta', {
      method: 'POST',
      body: JSON.stringify({ patient_id: patientId, org_id: physician.orgId, sex: 'F', birth_date: '1985-03-01', program_started_on: '2026-04-02', last_activity_at: new Date().toISOString() }),
    });

    otherPhysician = await createOrgAndMember('physician');
    cleanupUserIds.push(otherPhysician.userId);
    otherPhysicianToken = await aal2For(otherPhysician.email, otherPhysician.password);
  });

  afterAll(async () => {
    while (cleanupUserIds.length) await deleteUser(cleanupUserIds.pop()!);
  });

  it('roster lists the physician own-org patient', async () => {
    const res = await rpc('physician_patient_roster', physicianToken, { p_search: null, p_filter: 'all', p_sort: 'recent', p_limit: 50, p_offset: 0 });
    expect(res.status).toBe(200);
    const rows = (await res.json()) as { patient_id: string }[];
    expect(rows.some((r) => r.patient_id === patientId)).toBe(true);
  });

  it('other clinic returns the SAME not-found response as an unknown id', async () => {
    const crossOrg = await rpc('open_patient_detail', otherPhysicianToken, { p_patient_id: patientId });
    const unknown = await rpc('open_patient_detail', otherPhysicianToken, { p_patient_id: unknownId });
    expect(crossOrg.status).toBe(unknown.status);
    const crossBody = await crossOrg.text();
    const unknownBody = await unknown.text();
    // both resolve to SQL NULL -> PostgREST returns the literal `null`
    expect(crossBody.trim()).toBe('null');
    expect(unknownBody.trim()).toBe('null');
    expect(crossBody).toBe(unknownBody);
  });

  it('open_patient_detail writes exactly one audit row per call', async () => {
    const before = await restAdmin(`audit_log?event_type=eq.patient_detail_opened&target_user_id=eq.${patientId}`);
    const beforeCount = ((await before.json()) as unknown[]).length;

    const open = await rpc('open_patient_detail', physicianToken, { p_patient_id: patientId });
    expect(open.status).toBe(200);
    const detail = (await open.json()) as Record<string, unknown> | null;
    expect(detail).not.toBeNull();

    const after = await restAdmin(`audit_log?event_type=eq.patient_detail_opened&target_user_id=eq.${patientId}`);
    const afterCount = ((await after.json()) as unknown[]).length;
    expect(afterCount).toBe(beforeCount + 1);
  });

  it('no `dose` key appears in any response payload', async () => {
    const detail = await (await rpc('open_patient_detail', physicianToken, { p_patient_id: patientId })).text();
    const trend = await (await rpc('patient_trend', physicianToken, { p_patient_id: patientId, p_analyte: 'hba1c', p_period: 'ALL' })).text();
    const latest = await (await rpc('patient_latest_results', physicianToken, { p_patient_id: patientId })).text();
    expect(detail.toLowerCase()).not.toContain('dose');
    expect(trend.toLowerCase()).not.toContain('dose');
    expect(latest.toLowerCase()).not.toContain('dose');
    // the treatment context is still there (name/start/status/source)
    expect(detail).toContain('Example GLP-1 medication (fictional)');
  });
});
