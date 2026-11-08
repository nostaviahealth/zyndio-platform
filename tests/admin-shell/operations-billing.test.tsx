// @vitest-environment jsdom
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

const mockGetOrgMonthlyUsageSummary = vi.fn();
const mockListOrgTerminationExports = vi.fn();
const mockRequestOrgTerminationExport = vi.fn();
const mockListPatientLegalHolds = vi.fn();
const mockListPatientDeletionConfirmations = vi.fn();
const mockSetPatientLegalHold = vi.fn();
const mockConfirmPatientDataDeletion = vi.fn();
const mockListSecurityIncidents = vi.fn();
const mockReportSecurityIncident = vi.fn();

vi.mock('../../lib/opsBillingApi', async (importOriginal) => {
  const actual = await importOriginal<typeof import('../../lib/opsBillingApi')>();
  return {
    ...actual,
    getOrgMonthlyUsageSummary: (...args: unknown[]) => mockGetOrgMonthlyUsageSummary(...args),
    listOrgTerminationExports: () => mockListOrgTerminationExports(),
    requestOrgTerminationExport: () => mockRequestOrgTerminationExport(),
    listPatientLegalHolds: () => mockListPatientLegalHolds(),
    listPatientDeletionConfirmations: () => mockListPatientDeletionConfirmations(),
    setPatientLegalHold: (...args: unknown[]) => mockSetPatientLegalHold(...args),
    confirmPatientDataDeletion: (...args: unknown[]) => mockConfirmPatientDataDeletion(...args),
    listSecurityIncidents: () => mockListSecurityIncidents(),
    reportSecurityIncident: (...args: unknown[]) => mockReportSecurityIncident(...args),
  };
});

import { calculateScheduleBOverage } from '../../lib/opsBillingApi';
import OperationsBilling from '../../pages/admin/OperationsBilling';
import { ToastProvider } from '../../components/ui/Toast';

function renderPage() {
  return render(
    <ToastProvider>
      <OperationsBilling />
    </ToastProvider>
  );
}

describe('PP-02 Schedule B tiered overage calculation', () => {
  it('includes 1 to 1,000 active patients at $0.00 overage', () => {
    expect(calculateScheduleBOverage(0).overage_fee_cents).toBe(0);
    const atCap = calculateScheduleBOverage(1000);
    expect(atCap.included_patients).toBe(1000);
    expect(atCap.billable_overage_patients).toBe(0);
    expect(atCap.overage_fee_cents).toBe(0);
    expect(atCap.overage_fee_usd).toBe(0);
  });

  it('prices tier 1 (1,001 to 2,500) at $0.50 per patient', () => {
    const res = calculateScheduleBOverage(1200);
    expect(res.billable_overage_patients).toBe(200);
    expect(res.tiers.tier_1001_2500_patients).toBe(200);
    expect(res.tiers.tier_1001_2500_cents).toBe(10000);
    expect(res.overage_fee_cents).toBe(10000);
    expect(res.overage_fee_usd).toBe(100);
  });

  it('prices tier 2 (2,501 to 10,000) at $0.35 per patient above 2,500', () => {
    const res = calculateScheduleBOverage(3000);
    expect(res.billable_overage_patients).toBe(2000);
    expect(res.tiers.tier_1001_2500_patients).toBe(1500);
    expect(res.tiers.tier_1001_2500_cents).toBe(75000);
    expect(res.tiers.tier_2501_10000_patients).toBe(500);
    expect(res.tiers.tier_2501_10000_cents).toBe(17500);
    expect(res.overage_fee_cents).toBe(92500);
    expect(res.overage_fee_usd).toBe(925);
  });

  it('prices tier 3 (10,001+) at $0.25 per patient above 10,000', () => {
    const res = calculateScheduleBOverage(11000);
    expect(res.billable_overage_patients).toBe(10000);
    expect(res.tiers.tier_1001_2500_cents).toBe(75000);
    expect(res.tiers.tier_2501_10000_cents).toBe(262500);
    expect(res.tiers.tier_10001_plus_patients).toBe(1000);
    expect(res.tiers.tier_10001_plus_cents).toBe(25000);
    expect(res.overage_fee_cents).toBe(362500);
    expect(res.overage_fee_usd).toBe(3625);
  });
});

describe('OperationsBilling page (PP-02, OPS-01, OPS-02, OPS-03)', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockGetOrgMonthlyUsageSummary.mockResolvedValue({
      org_id: '00000000-0000-0000-0000-00000000000a',
      month: '2026-11-01',
      active_patients_total: 3000,
      sign_in_count: 1800,
      data_processed_count: 1200,
      included_patients: 1000,
      billable_overage_patients: 2000,
      overage_fee_cents: 92500,
      overage_fee_usd: 925,
      tiers: {
        tier_1001_2500_patients: 1500,
        tier_1001_2500_cents: 75000,
        tier_2501_10000_patients: 500,
        tier_2501_10000_cents: 17500,
        tier_10001_plus_patients: 0,
        tier_10001_plus_cents: 0,
      },
    });
    mockListOrgTerminationExports.mockResolvedValue([]);
    mockListPatientLegalHolds.mockResolvedValue([]);
    mockListPatientDeletionConfirmations.mockResolvedValue([]);
    mockListSecurityIncidents.mockResolvedValue([]);
  });

  it('renders PP-02 monthly active patient counts and Schedule B tier breakdown', async () => {
    renderPage();
    await waitFor(() =>
      expect(screen.getByTestId('active-patients-total')).toHaveTextContent('3,000')
    );
    expect(screen.getByText(/1,800 sign-in · 1,200 data processed/)).toBeInTheDocument();
    expect(screen.getByTestId('billable-overage-patients')).toHaveTextContent('2,000');
    expect(screen.getByTestId('overage-fee-usd')).toHaveTextContent('$925.00');
    expect(screen.getByRole('table', { name: 'Schedule B overage tiers' })).toBeInTheDocument();
  });

  it('generates a Clause 6.6 termination export manifest (OPS-01)', async () => {
    const user = userEvent.setup();
    mockRequestOrgTerminationExport.mockResolvedValue({
      id: 'exp-001',
      org_id: '00000000-0000-0000-0000-00000000000a',
      requested_by: '00000000-0000-0000-0000-0000000a0001',
      requested_at: '2026-11-05T10:00:00Z',
      due_at: '2026-12-05T10:00:00Z',
      readonly_until: '2027-01-04T10:00:00Z',
      status: 'completed',
      manifest: {
        schema_version: '1.0',
        clause: '6.6',
        org_id: '00000000-0000-0000-0000-00000000000a',
        patient_count: 14,
        lab_report_count: 38,
        patients: [],
        documents: [],
        sha256_manifest: 'a'.repeat(64),
      },
    });

    renderPage();
    await waitFor(() => expect(screen.getByTestId('active-patients-total')).toBeInTheDocument());

    await user.click(screen.getByRole('button', { name: 'Generate termination export' }));

    await waitFor(() =>
      expect(screen.getByTestId('termination-export-card')).toBeInTheDocument()
    );
    expect(screen.getByText(/14 patients · 38 lab reports/)).toBeInTheDocument();
    expect(screen.getByText(new RegExp('a'.repeat(64)))).toBeInTheDocument();
  });

  it('surfaces legal hold block and issues written deletion certificate when permitted (OPS-02)', async () => {
    const user = userEvent.setup();
    mockConfirmPatientDataDeletion
      .mockRejectedValueOnce(new Error('patient_under_legal_hold'))
      .mockResolvedValueOnce({
        id: 'del-001',
        org_id: '00000000-0000-0000-0000-00000000000a',
        patient_ref: 'PAT-0123456789abcdef',
        deleted_by: '00000000-0000-0000-0000-0000000a0001',
        deleted_at: '2026-11-05T11:00:00Z',
        confirmation_code: 'DEL-1A2B3C4D5E6F',
        certificate_sha256: 'b'.repeat(64),
        summary: {
          deleted_lab_reports: 2,
          deleted_profiles: 1,
          deleted_consents: 1,
          pii_scrubbed: true,
        },
      });

    renderPage();
    await waitFor(() => expect(screen.getByTestId('active-patients-total')).toBeInTheDocument());

    await user.type(
      screen.getByLabelText('Patient UUID'),
      '00000000-0000-0000-0000-0000000a1001'
    );

    // First attempt is blocked by legal hold
    await user.click(
      screen.getByRole('button', { name: 'Delete patient data and issue certificate' })
    );
    expect(
      await screen.findByText(/Deletion refused: patient record is under an active legal hold/)
    ).toBeInTheDocument();

    // Second attempt succeeds and renders the DEL-... certificate
    await user.click(
      screen.getByRole('button', { name: 'Delete patient data and issue certificate' })
    );
    await waitFor(() =>
      expect(screen.getByTestId('deletion-certificate-card')).toBeInTheDocument()
    );
    expect(screen.getByText('DEL-1A2B3C4D5E6F')).toBeInTheDocument();
    expect(screen.getByText(/PAT-0123456789abcdef/)).toBeInTheDocument();
  });

  it('logs a Clause 8.8 security incident with 72-hour notification deadline (OPS-03)', async () => {
    const user = userEvent.setup();
    mockReportSecurityIncident.mockResolvedValue({
      id: 'inc-001',
      org_id: '00000000-0000-0000-0000-00000000000a',
      severity: 'P1',
      title: 'Confirmed credential stuffing spike',
      summary: 'Edge rate limiter mitigated automated login spike with zero unauthorized access.',
      confirmed_at: '2026-11-05T12:00:00Z',
      notify_deadline_at: '2026-11-08T12:00:00Z',
      notified_at: '2026-11-05T12:00:00Z',
      status: 'notified',
      created_by: '00000000-0000-0000-0000-0000000a0001',
      within_72h_sla: true,
    });

    renderPage();
    await waitFor(() => expect(screen.getByTestId('active-patients-total')).toBeInTheDocument());

    await user.type(
      screen.getByLabelText('Incident title'),
      'Confirmed credential stuffing spike'
    );
    await user.type(
      screen.getByLabelText('Incident summary (no PHI)'),
      'Edge rate limiter mitigated automated login spike with zero unauthorized access.'
    );
    await user.click(screen.getByRole('button', { name: 'Report security incident' }));

    await waitFor(() =>
      expect(screen.getByTestId('security-incident-card')).toBeInTheDocument()
    );
    expect(screen.getByText('[P1] Confirmed credential stuffing spike')).toBeInTheDocument();
    expect(screen.getByText(/2026-11-08 12:00 UTC/)).toBeInTheDocument();
  });
});
