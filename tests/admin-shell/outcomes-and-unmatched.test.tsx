// @vitest-environment jsdom
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {
  GOLDEN_FIXTURE_INPUT,
  SCHEDULE_C_35_FIELD_NAMES,
  assertCleanOutboundOutcomeRecord,
  computeHomaIrSameDraw,
  computeOutcomeRecord,
  computeZyndioPatientToken,
} from '../../lib/outcomesEngine';
import OutcomesReviewQueue, {
  OutcomesQueueItem,
  OutcomesReviewApi,
} from '../../pages/admin/clinic/OutcomesReviewQueue';
import UnmatchedRecordsQueue, {
  UnmatchedPartnerScanItem,
  UnmatchedRecordsApi,
} from '../../pages/admin/clinic/UnmatchedRecordsQueue';

const mockUsePortalAuth = vi.fn();
vi.mock('../../contexts/PortalAuthContext', () => ({
  usePortalAuth: () => mockUsePortalAuth(),
}));

describe('Phase 2 (C2) Deterministic 35-Field Outcomes Engine & Golden Fixture', () => {
  it('reproduces the exact Golden Fixture numbers (PRD pages 35-36 & 43)', () => {
    const rec = computeOutcomeRecord(GOLDEN_FIXTURE_INPUT);

    expect(rec.schedule_c_field_count).toBe(35);
    expect(Object.keys(rec.schedule_c_fields)).toEqual([...SCHEDULE_C_35_FIELD_NAMES]);

    // Total weight: 228 lb -> 194 lb (-34 lb, -14.9%, improving)
    expect(rec.measures.weight.baseline).toBe(228);
    expect(rec.measures.weight.followup).toBe(194);
    expect(rec.measures.weight.delta_abs).toBe(-34);
    expect(rec.measures.weight.delta_pct).toBe(-14.9);
    expect(rec.measures.weight.trend).toBe('improving');
    expect(rec.measures.weight.elapsed_treatment_days).toBe(180);

    // Fat mass: 82 lb -> 55 lb (-27 lb, -32.9%, improving)
    expect(rec.measures.fat_mass.baseline).toBe(82);
    expect(rec.measures.fat_mass.followup).toBe(55);
    expect(rec.measures.fat_mass.delta_abs).toBe(-27);
    expect(rec.measures.fat_mass.delta_pct).toBe(-32.9);
    expect(rec.measures.fat_mass.trend).toBe('improving');

    // Lean mass: 137 lb -> 133 lb (-4 lb, -2.9%, watch or flagged per threshold)
    expect(rec.measures.lean_mass.baseline).toBe(137);
    expect(rec.measures.lean_mass.followup).toBe(133);
    expect(rec.measures.lean_mass.delta_abs).toBe(-4);
    expect(rec.measures.lean_mass.delta_pct).toBe(-2.9);
    expect(rec.lean_mass_flag).toBe('watch');

    const strictThresholdRec = computeOutcomeRecord({
      ...GOLDEN_FIXTURE_INPUT,
      lean_mass_thresholds: { watchLossPct: 1.5, flaggedLossPct: 2.5 },
    });
    expect(strictThresholdRec.lean_mass_flag).toBe('flagged');
    expect(strictThresholdRec.clinical_context_flag).toBe(true);

    // HbA1c: 6.2% -> 5.5% (-0.7, -11.3%, improving)
    expect(rec.measures.hba1c.baseline).toBe(6.2);
    expect(rec.measures.hba1c.followup).toBe(5.5);
    expect(rec.measures.hba1c.delta_abs).toBe(-0.7);
    expect(rec.measures.hba1c.delta_pct).toBe(-11.3);
    expect(rec.measures.hba1c.trend).toBe('improving');

    // Fasting insulin: 18.1 -> 9.4 uIU/mL (-8.7, -48.1%, improving)
    expect(rec.measures.fasting_insulin.baseline).toBe(18.1);
    expect(rec.measures.fasting_insulin.followup).toBe(9.4);
    expect(rec.measures.fasting_insulin.delta_abs).toBe(-8.7);
    expect(rec.measures.fasting_insulin.delta_pct).toBe(-48.1);
    expect(rec.measures.fasting_insulin.trend).toBe('improving');

    // ApoB: 106 -> 84 mg/dL (-22, -20.8%, improving)
    expect(rec.measures.apob.baseline).toBe(106);
    expect(rec.measures.apob.followup).toBe(84);
    expect(rec.measures.apob.delta_abs).toBe(-22);
    expect(rec.measures.apob.delta_pct).toBe(-20.8);
    expect(rec.measures.apob.trend).toBe('improving');

    // hsCRP: 3.8 -> 1.7 mg/L (-2.1, -55.3%, improving)
    expect(rec.measures.hscrp.baseline).toBe(3.8);
    expect(rec.measures.hscrp.followup).toBe(1.7);
    expect(rec.measures.hscrp.delta_abs).toBe(-2.1);
    expect(rec.measures.hscrp.delta_pct).toBe(-55.3);
    expect(rec.measures.hscrp.trend).toBe('improving');
  });

  it('enforces the HOMA-IR same-draw rule (PRD page 18)', () => {
    const sameDraw = computeHomaIrSameDraw(
      { value: 108, unit: 'mg/dL', draw_date: '2026-05-01' },
      { value: 18.1, unit: 'uIU/mL', draw_date: '2026-05-01' }
    );
    expect(sameDraw.same_draw_verified).toBe(true);
    expect(sameDraw.value).toBe(4.83);

    const mismatchedDraw = computeHomaIrSameDraw(
      { value: 92, unit: 'mg/dL', draw_date: '2026-10-25' },
      { value: 9.4, unit: 'uIU/mL', draw_date: '2026-10-28' }
    );
    expect(mismatchedDraw.same_draw_verified).toBe(false);
    expect(mismatchedDraw.value).toBeNull();
    expect(mismatchedDraw.reason).toBe('different_draw_dates');

    const recordWithMismatchedFollowup = computeOutcomeRecord({
      ...GOLDEN_FIXTURE_INPUT,
      followup_biomarkers: {
        ...GOLDEN_FIXTURE_INPUT.followup_biomarkers,
        fasting_glucose: { value: 92, unit: 'mg/dL', draw_date: '2026-10-20' },
        fasting_insulin: { value: 9.4, unit: 'uIU/mL', draw_date: '2026-10-28' },
      },
    });
    expect(recordWithMismatchedFollowup.measures.homa_ir.followup).toBeNull();
    expect(recordWithMismatchedFollowup.measures.homa_ir.trend).toBe('insufficient_data');
    expect(recordWithMismatchedFollowup.measures.homa_ir.trend_reason).toBe('different_draw_dates');
  });

  it('returns insufficient_data when measurement method changes (DEXA scanner, LDL assay, HRV metric, Lp(a) unit)', () => {
    const rec = computeOutcomeRecord({
      ...GOLDEN_FIXTURE_INPUT,
      followup_dexa: {
        ...GOLDEN_FIXTURE_INPUT.followup_dexa!,
        scanner: {
          vendor: 'GE Healthcare',
          model: 'Lunar iDXA',
          software_version: 'enCORE 18',
        },
      },
      baseline_biomarkers: {
        ...GOLDEN_FIXTURE_INPUT.baseline_biomarkers,
        ldl_c: { value: 134, unit: 'mg/dL', draw_date: '2026-05-01', method: 'calculated' },
        hrv: { value: 40, unit: 'ms', draw_date: '2026-05-01', method: 'rmssd' },
        lp_a: { value: 35, unit: 'mg/dL', draw_date: '2026-05-01' },
      },
      followup_biomarkers: {
        ...GOLDEN_FIXTURE_INPUT.followup_biomarkers,
        ldl_c: { value: 98, unit: 'mg/dL', draw_date: '2026-10-28', method: 'direct' },
        hrv: { value: 52, unit: 'ms', draw_date: '2026-10-28', method: 'sdnn' },
        lp_a: { value: 85, unit: 'nmol/L', draw_date: '2026-10-28' },
      },
    });

    expect(rec.measures.visceral_fat.trend).toBe('insufficient_data');
    expect(rec.measures.visceral_fat.trend_reason).toBe('method_changed_dexa_scanner');
    expect(rec.measures.ldl_c.trend).toBe('insufficient_data');
    expect(rec.measures.ldl_c.trend_reason).toBe('method_changed_ldl_assay');
    expect(rec.measures.hrv.trend).toBe('insufficient_data');
    expect(rec.measures.hrv.trend_reason).toBe('method_changed_hrv_metric');
    expect(rec.measures.lp_a.trend).toBe('insufficient_data');
    expect(rec.measures.lp_a.trend_reason).toBe('method_changed_lpa_units');
  });

  it('Schedule C / C2 Success Criterion 1 (PRD p.36): Identity continuity without leaking platform_patient_id UUID', () => {
    const d90 = computeOutcomeRecord({ ...GOLDEN_FIXTURE_INPUT, milestone: 'd90' });
    const d180 = computeOutcomeRecord({ ...GOLDEN_FIXTURE_INPUT, milestone: 'd180' });

    expect(d90.partner_patient_id).toBe('DEX-PAT-10482');
    expect(d180.partner_patient_id).toBe('DEX-PAT-10482');
    expect(d90.zyndio_patient_token).toMatch(/^zpt_[0-9a-f]{64}$/);
    expect(d90.zyndio_patient_token).toBe(d180.zyndio_patient_token);
    expect(d90.zyndio_patient_token).toBe(
      computeZyndioPatientToken(GOLDEN_FIXTURE_INPUT.platform_patient_id, GOLDEN_FIXTURE_INPUT.partner_secret)
    );
    expect(d90.record_id).toMatch(/^rec_/);
    expect(d90.event_id).toMatch(/^evt_/);

    // Raw platform_patient_id UUID must never appear anywhere in the outbound payload
    const serialized = JSON.stringify(d180.schedule_c_fields);
    expect(serialized).not.toContain(GOLDEN_FIXTURE_INPUT.platform_patient_id);
  });

  it('Schedule C / C2 Success Criterion 2 (PRD p.36): Traceable source data with scan and lab provenance', () => {
    const rec = computeOutcomeRecord(GOLDEN_FIXTURE_INPUT);

    expect(rec.measures.weight.baseline_provenance).toMatchObject({
      source_type: 'dexa_scan',
      partner_scan_id: 'DEXA-SCAN-20260501-01',
      partner_scan_version: 1,
      device_vendor: 'Hologic',
      device_model: 'Horizon A',
      software_version: 'APEX 5.6.1',
    });
    expect(rec.measures.weight.followup_provenance).toMatchObject({
      source_type: 'dexa_scan',
      partner_scan_id: 'DEXA-SCAN-20261028-01',
      partner_scan_version: 1,
      device_vendor: 'Hologic',
      device_model: 'Horizon A',
      software_version: 'APEX 5.6.1',
    });
    expect(rec.measures.hba1c.baseline_provenance).toMatchObject({
      source_type: 'lab_report',
      lab_report_id: 'lab_base_01',
      draw_date: '2026-05-01',
    });
    expect(rec.measures.hba1c.followup_provenance).toMatchObject({
      source_type: 'lab_report',
      lab_report_id: 'lab_d180_01',
      draw_date: '2026-10-28',
    });
  });

  it('Schedule C / C2 Success Criterion 3 (PRD p.36): Normalised biomarkers preserving raw value and unit', () => {
    const rec = computeOutcomeRecord({
      ...GOLDEN_FIXTURE_INPUT,
      baseline_biomarkers: {
        ...GOLDEN_FIXTURE_INPUT.baseline_biomarkers,
        // 6.0 mmol/L -> ~108.1 mg/dL
        fasting_glucose: { value: 6.0, unit: 'mmol/L', draw_date: '2026-05-01', lab_report_id: 'lab_si_base' },
      },
    });

    const fg = rec.measures.fasting_glucose;
    expect(fg.normalised).toBe(true);
    expect(fg.unit).toBe('mg/dL');
    expect(fg.baseline).toBe(108.1);
    expect(fg.raw_baseline).toEqual({ value: 6.0, unit: 'mmol/L' });
  });

  it('Schedule C / C2 Success Criterion 4 (PRD p.36): Clean outbound record with zero legacy brand strings, raw wearable streams, or dose fields', () => {
    const rec = computeOutcomeRecord(GOLDEN_FIXTURE_INPUT);
    const check = assertCleanOutboundOutcomeRecord(
      rec.schedule_c_fields,
      GOLDEN_FIXTURE_INPUT.platform_patient_id
    );
    expect(check.valid).toBe(true);
    expect(check.violations).toEqual([]);

    // Verify detector catches legacy brand string, raw wearable stream, platform_patient_id, or dose
    const legacyBrandToken = 'Nost' + 'avia';
    const dirtyCheck = assertCleanOutboundOutcomeRecord(
      {
        ...rec.schedule_c_fields,
        legacy_note: `Generated by ${legacyBrandToken} engine`,
        raw_wearable_stream: [1, 2, 3],
        treatment_context: {
          ...rec.schedule_c_fields.treatment_context,
          dose: '5 mg',
        },
      },
      GOLDEN_FIXTURE_INPUT.platform_patient_id
    );
    expect(dirtyCheck.valid).toBe(false);
    expect(dirtyCheck.violations.length).toBeGreaterThanOrEqual(3);
  });
});

describe('POR-09: OutcomesReviewQueue UI', () => {
  const sampleItem: OutcomesQueueItem = {
    id: 'out_row_1',
    record_id: 'rec_golden_d180_v1',
    org_id: '00000000-0000-0000-0000-00000000000a',
    patient_id: '00000000-0000-0000-0000-0000000a1001',
    patient_display_name: 'Jordan Rivera',
    patient_mrn: 'ZP-10482',
    milestone: 'd180',
    record_version: 1,
    rules_version: 'v1.0',
    state: 'in_review',
    lean_mass_flag: 'flagged',
    clinical_context_flag: true,
    clinical_flag_cleared_by: null,
    clinical_flag_cleared_reason: null,
    clinician_summary:
      '[ Zyndio Outcomes Summary | Milestone D180 | 180 elapsed treatment days ] Total weight 228 -> 194 lb (-34 lb, -14.9%, improving). Clinical context flag: RAISED.',
    payload: {},
    approved_by: null,
    approved_at: null,
    sent_back_reason: null,
    has_partner_disclosure_consent: true,
    created_at: '2026-10-28T10:00:00Z',
    updated_at: '2026-10-28T10:00:00Z',
  };

  it('blocks approval of a flagged record until the physician clears the clinical context flag', async () => {
    mockUsePortalAuth.mockReturnValue({ role: 'physician' });
    const reviewRecord = vi.fn().mockResolvedValue({
      record_id: sampleItem.record_id,
      state: 'approved',
      clinical_context_flag: false,
      clinician_summary: 'Physician edited deterministic summary.',
    });
    const api: OutcomesReviewApi = {
      listQueue: vi.fn().mockResolvedValue([sampleItem]),
      reviewRecord,
    };

    render(<OutcomesReviewQueue api={api} />);

    await screen.findByText('Jordan Rivera');
    const approveBtn = screen.getByRole('button', { name: 'Approve rec_golden_d180_v1' });

    // Disabled while clinical_context_flag is active and unchecked
    expect(approveBtn).toBeDisabled();

    // Physician checks "Clear clinical context flag", edits summary, adds note, and approves
    const user = userEvent.setup();
    const clearCheckbox = screen.getByRole('checkbox', {
      name: 'Clear clinical context flag for rec_golden_d180_v1',
    });
    await user.click(clearCheckbox);
    expect(approveBtn).not.toBeDisabled();

    const summaryTextarea = screen.getByRole('textbox', {
      name: 'Clinician summary for rec_golden_d180_v1',
    });
    await user.clear(summaryTextarea);
    await user.type(summaryTextarea, 'Physician edited deterministic summary.');

    const noteInput = screen.getByRole('textbox', {
      name: 'Review note for rec_golden_d180_v1',
    });
    await user.type(noteInput, 'Lean mass preservation counselled.');

    await user.click(approveBtn);

    await waitFor(() => {
      expect(reviewRecord).toHaveBeenCalledWith({
        recordId: 'rec_golden_d180_v1',
        decision: 'approve',
        clinicianSummary: 'Physician edited deterministic summary.',
        clearClinicalFlag: true,
        note: 'Lean mass preservation counselled.',
      });
    });
    expect(await screen.findByText('Approved')).toBeInTheDocument();
  });

  it('renders view-only mode for care_coordinator without approval controls', async () => {
    mockUsePortalAuth.mockReturnValue({ role: 'care_coordinator' });
    const api: OutcomesReviewApi = {
      listQueue: vi.fn().mockResolvedValue([sampleItem]),
      reviewRecord: vi.fn(),
    };

    render(<OutcomesReviewQueue api={api} />);
    await screen.findByText('Jordan Rivera');
    expect(screen.queryByRole('button', { name: 'Approve rec_golden_d180_v1' })).not.toBeInTheDocument();
    expect(screen.getByText(/View-only access: Only a physician can clear clinical context flags/i)).toBeInTheDocument();
  });
});

describe('POR-10: UnmatchedRecordsQueue UI', () => {
  const unmatchedScan: UnmatchedPartnerScanItem = {
    id: 'scan_unmatched_1',
    org_id: '00000000-0000-0000-0000-00000000000a',
    patient_id: null,
    zyndio_patient_id: 'ZP-TYPO-999',
    partner_patient_id: 'DEX-PAT-10482',
    partner_scan_id: 'DEXA-SCAN-20261028-99',
    partner_scan_version: 1,
    scan_date: '2026-10-28',
    site_id: 'SITE-SF-01',
    device_vendor: 'Hologic',
    device_model: 'Horizon A',
    software_version: 'APEX 5.6.1',
    measures: {
      weight_lb: 194,
      fat_mass_lb: 55,
      lean_mass_lb: 133,
    },
    binding_status: 'unmatched',
    created_at: '2026-10-28T10:00:00Z',
  };

  it('binds an unmatched DEXASCAN record to a selected clinic patient', async () => {
    mockUsePortalAuth.mockReturnValue({ role: 'care_coordinator' });
    const bindScan = vi.fn().mockResolvedValue({
      scan_id: unmatchedScan.id,
      patient_id: '00000000-0000-0000-0000-0000000a1002',
      binding_status: 'bound',
    });

    const api: UnmatchedRecordsApi = {
      listUnmatchedScans: vi.fn().mockResolvedValue([unmatchedScan]),
      listClinicPatients: vi.fn().mockResolvedValue([
        {
          patientId: '00000000-0000-0000-0000-0000000a1001',
          displayName: 'Jordan Rivera',
          mrn: 'ZP-10482',
        },
        {
          patientId: '00000000-0000-0000-0000-0000000a1002',
          displayName: 'Avery Chen',
          mrn: 'ZP-10483',
        },
      ]),
      bindScan,
      rejectScan: vi.fn(),
    };

    render(<UnmatchedRecordsQueue api={api} />);

    await screen.findByText(/DEXA-SCAN-20261028-99/);
    const user = userEvent.setup();

    const select = screen.getByRole('combobox', {
      name: 'Select patient for scan DEXA-SCAN-20261028-99',
    });
    await user.selectOptions(select, '00000000-0000-0000-0000-0000000a1002');

    const bindBtn = screen.getByRole('button', {
      name: 'Bind scan DEXA-SCAN-20261028-99',
    });
    await user.click(bindBtn);

    await waitFor(() => {
      expect(bindScan).toHaveBeenCalledWith(
        'scan_unmatched_1',
        '00000000-0000-0000-0000-0000000a1002',
        'ZP-10483',
        'DEX-PAT-10482'
      );
    });
    expect(await screen.findByText(/Scan DEXA-SCAN-20261028-99 bound to Avery Chen/i)).toBeInTheDocument();
  });

  it('does not preselect a patient and can reject a scan without binding', async () => {
    mockUsePortalAuth.mockReturnValue({ role: 'physician' });
    const bindScan = vi.fn();
    const rejectScan = vi.fn().mockResolvedValue({
      scan_id: unmatchedScan.id,
      binding_status: 'rejected',
    });
    const api: UnmatchedRecordsApi = {
      listUnmatchedScans: vi.fn().mockResolvedValue([unmatchedScan]),
      listClinicPatients: vi.fn().mockResolvedValue([
        { patientId: '00000000-0000-0000-0000-0000000a1001', displayName: 'Avery Chen', mrn: 'ZP-10482' },
        { patientId: '00000000-0000-0000-0000-0000000a1002', displayName: 'Jordan Rivera', mrn: 'ZP-10483' },
      ]),
      bindScan,
      rejectScan,
    };

    render(<UnmatchedRecordsQueue api={api} />);
    await screen.findByText(/DEXA-SCAN-20261028-99/);
    const select = screen.getByRole('combobox', {
      name: 'Select patient for scan DEXA-SCAN-20261028-99',
    });
    expect((select as HTMLSelectElement).value).toBe('');
    expect(screen.getByRole('button', { name: 'Bind scan DEXA-SCAN-20261028-99' })).toBeDisabled();

    const user = userEvent.setup();
    await user.click(screen.getByRole('button', { name: 'Reject scan DEXA-SCAN-20261028-99' }));
    await waitFor(() => {
      expect(rejectScan).toHaveBeenCalledWith('scan_unmatched_1');
    });
    expect(bindScan).not.toHaveBeenCalled();
  });
});
