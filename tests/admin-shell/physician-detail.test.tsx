// @vitest-environment jsdom
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor, within, fireEvent } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';

import PhysicianPatientDetail from '../../pages/admin/clinic/PhysicianPatientDetail';
import { ClinicalApi, LatestResult, PatientDetail, TrendPoint } from '../../lib/clinicalApi';

const NOW = new Date('2026-10-18T10:00:00Z');

const DETAIL: PatientDetail = {
  patientId: 'p-jordan',
  displayName: 'Jordan Rivera',
  mrn: 'ZP-10482',
  sex: 'female',
  birthDate: '1985-03-01',
  programStartedOn: '2026-04-02T00:00:00Z',
  lastActivityAt: '2026-10-18T09:12:00Z',
  treatment: {
    name: 'Example GLP-1 medication (fictional)',
    startedOn: '2026-04-02T00:00:00Z',
    status: 'Active',
    source: 'Zyndio record, Oct 20, 2026',
  },
};

const HBA1C: LatestResult = {
  analyteKey: 'hba1c',
  analyteLabel: 'HbA1c',
  value: 5.5,
  originalValue: null,
  unit: '%',
  status: 'within_range',
  isUnmapped: false,
  rangeLow: null,
  rangeHigh: 5.7,
  takenAt: '2026-10-14T12:00:00Z',
};

const HSCRP: LatestResult = {
  analyteKey: 'hscrp',
  analyteLabel: 'hsCRP',
  value: 1.7,
  originalValue: null,
  unit: 'mg/L',
  status: 'needs_review',
  isUnmapped: false,
  rangeLow: null,
  rangeHigh: null,
  takenAt: '2026-10-14T12:00:00Z',
};

const TREND: TrendPoint[] = [
  { takenAt: '2026-04-02T00:00:00Z', value: 6.2, originalValue: null, unit: '%', status: 'baseline', rangeLow: null, rangeHigh: 5.7 },
  { takenAt: '2026-08-06T00:00:00Z', value: 5.7, originalValue: null, unit: '%', status: 'within_range', rangeLow: null, rangeHigh: 5.7 },
  { takenAt: '2026-10-14T12:00:00Z', value: 5.5, originalValue: null, unit: '%', status: 'within_range', rangeLow: null, rangeHigh: 5.7 },
];

function makeApi(over: Partial<ClinicalApi> = {}): ClinicalApi {
  return {
    fetchRoster: vi.fn(),
    fetchChipCounts: vi.fn(),
    openPatientDetail: vi.fn().mockResolvedValue(DETAIL),
    fetchLatestResults: vi.fn().mockResolvedValue([HBA1C, HSCRP]),
    fetchTrend: vi.fn().mockResolvedValue(TREND),
    ...over,
  };
}

function renderDetail(api: ClinicalApi, props: Partial<React.ComponentProps<typeof PhysicianPatientDetail>> = {}) {
  return render(
    <MemoryRouter>
      <PhysicianPatientDetail api={api} now={NOW} patientId="p-jordan" flags={['question_waiting']} questionsCount={1} {...props} />
    </MemoryRouter>
  );
}

describe('PhysicianPatientDetail', () => {
  it('renders the header, treatment strip (no dose) and tabs', async () => {
    renderDetail(makeApi());
    expect(await screen.findByRole('heading', { name: 'Jordan Rivera' })).toBeInTheDocument();
    expect(screen.getByText('ZP-10482 · 41 · Female · Week 28 of program')).toBeInTheDocument();
    expect(screen.getByText('Example GLP-1 medication (fictional)')).toBeInTheDocument();
    expect(screen.getByRole('tab', { name: 'Labs' })).toHaveAttribute('aria-selected', 'true');
    expect(screen.getByRole('tab', { name: 'Questions and notes (1)' })).toHaveAttribute('aria-disabled', 'true');
    // No dose text anywhere.
    expect(document.body.textContent).not.toMatch(/dose/i);
    expect(document.body.textContent).not.toMatch(/mg weekly/i);
  });

  it('back link points at /admin/patients', async () => {
    renderDetail(makeApi());
    await screen.findByRole('heading', { name: 'Jordan Rivera' });
    expect(screen.getByRole('link', { name: 'Patients' })).toHaveAttribute('href', '/admin/patients');
  });

  it('calls open_patient_detail exactly once per open, even under StrictMode', async () => {
    const api = makeApi();
    render(
      <React.StrictMode>
        <MemoryRouter>
          <PhysicianPatientDetail api={api} now={NOW} patientId="p-jordan" />
        </MemoryRouter>
      </React.StrictMode>
    );
    await screen.findByRole('heading', { name: 'Jordan Rivera' });
    expect(api.openPatientDetail).toHaveBeenCalledTimes(1);
  });

  it('maps a null detail payload to the shared not-found view (no "forbidden")', async () => {
    const api = makeApi({ openPatientDetail: vi.fn().mockResolvedValue(null) });
    renderDetail(api);
    expect(await screen.findByText("We can't show this patient")).toBeInTheDocument();
    expect(document.body.textContent).not.toMatch(/forbidden/i);
  });

  it("not-found: Ava's exact copy, primary button to /admin/patients, page title set", async () => {
    const api = makeApi({ openPatientDetail: vi.fn().mockResolvedValue(null) });
    renderDetail(api);
    expect(await screen.findByText("We can't show this patient")).toBeInTheDocument();
    expect(
      screen.getByText("The link may be wrong, or they're no longer in your clinic's program.")
    ).toBeInTheDocument();
    const button = screen.getByRole('link', { name: 'Back to Patients' });
    expect(button).toHaveAttribute('href', '/admin/patients');
    expect(screen.getByRole('heading', { name: 'Patient not found' })).toBeInTheDocument();
  });

  it('not-found: same view for unknown, other-clinic and no-access (no hint the patient exists)', async () => {
    const unknown = makeApi({ openPatientDetail: vi.fn().mockResolvedValue(null) });
    const { unmount } = renderDetail(unknown);
    const firstTree = await screen.findByText("We can't show this patient");
    expect(firstTree).toBeInTheDocument();
    unmount();

    const otherClinic = makeApi({ openPatientDetail: vi.fn().mockResolvedValue(null) });
    renderDetail(otherClinic, { patientId: 'p-other-clinic' });
    expect(await screen.findByText("We can't show this patient")).toBeInTheDocument();
  });

  it('Timeline, Pre-visit brief and Export data each show a Soon tag, are aria-disabled but focusable, and show a tooltip on hover and keyboard focus', async () => {
    const user = userEvent.setup();
    renderDetail(makeApi());
    await screen.findByRole('heading', { name: 'Jordan Rivera' });

    const timelineTab = screen.getByRole('tab', { name: /Timeline/ });
    const previsitTab = screen.getByRole('tab', { name: /Pre-visit brief/ });
    const exportButton = screen.getByRole('button', { name: /Export data/ });

    for (const control of [timelineTab, previsitTab, exportButton]) {
      expect(control).toHaveAttribute('aria-disabled', 'true');
      expect(control).not.toBeDisabled();
    }
    expect(within(timelineTab).getByText('Soon')).toBeInTheDocument();
    expect(within(previsitTab).getByText('Soon')).toBeInTheDocument();
    expect(within(exportButton).getByText('Soon')).toBeInTheDocument();

    await user.hover(timelineTab);
    expect(await screen.findByRole('tooltip')).toHaveTextContent('Timeline is coming in the next update.');
    await user.unhover(timelineTab);

    fireEvent.focus(timelineTab);
    expect(await screen.findByRole('tooltip')).toHaveTextContent('Timeline is coming in the next update.');
    fireEvent.blur(timelineTab);
    await waitFor(() => expect(screen.queryByRole('tooltip')).not.toBeInTheDocument());

    fireEvent.focus(previsitTab);
    expect(await screen.findByRole('tooltip')).toHaveTextContent('Pre-visit briefs are coming in the next update.');
    fireEvent.blur(previsitTab);
    await waitFor(() => expect(screen.queryByRole('tooltip')).not.toBeInTheDocument());

    fireEvent.focus(exportButton);
    expect(await screen.findByRole('tooltip')).toHaveTextContent('Export is coming in the next update.');
    fireEvent.blur(exportButton);

    expect(document.body.textContent).not.toMatch(/Not available yet/);
  });

  it('default state: selects HbA1c, shows the trend meta and an accessible chart label', async () => {
    renderDetail(makeApi());
    expect(await screen.findByText('Average blood sugar over the past 2–3 months')).toBeInTheDocument();
    expect(await screen.findByText(/−0.7 points since baseline \(Apr 2\)/)).toBeInTheDocument();
    expect(
      await screen.findByRole('img', { name: /HbA1c chart: Apr 2 6.2%, Aug 6 5.7%, Oct 14 5.5%/ })
    ).toBeInTheDocument();
    expect(screen.getAllByText('View report')[0]).toHaveAttribute('aria-disabled', 'true');
    expect(document.body.textContent).not.toMatch(/Not available yet/);
  });

  it('single state: one trend point shows "One result so far" and the caveat, no chart', async () => {
    const api = makeApi({ fetchLatestResults: vi.fn().mockResolvedValue([HBA1C]), fetchTrend: vi.fn().mockResolvedValue([TREND[2]]) });
    renderDetail(api);
    expect(await screen.findByText('One result so far')).toBeInTheDocument();
    expect(screen.getByText(/A trend appears when the next HbA1c result arrives/)).toBeInTheDocument();
    expect(screen.queryByRole('img', { name: /chart/ })).not.toBeInTheDocument();
  });

  it('needs-review state: banner + disabled "Check in report", never used in trends', async () => {
    const api = makeApi();
    renderDetail(api, { initialSelectedKey: 'hscrp' });
    await screen.findByRole('heading', { name: 'Jordan Rivera' });
    expect(screen.getByText(/isn't used in trends or outcomes until someone checks it/)).toBeInTheDocument();
    const btn = screen.getByRole('button', { name: /Check in report/ });
    expect(btn).toBeDisabled();
    // needs-review markers are never fed to the trend RPC.
    expect(api.fetchTrend).not.toHaveBeenCalledWith('p-jordan', 'hscrp', expect.anything());
    expect(document.body.textContent).not.toMatch(/Not available yet/);
  });

  it('empty state: no markers shows "No lab results yet"', async () => {
    const api = makeApi({ fetchLatestResults: vi.fn().mockResolvedValue([]) });
    renderDetail(api);
    expect(await screen.findByText('No lab results yet')).toBeInTheDocument();
  });

  it('error state: latest-results failure shows the banner + Try again', async () => {
    const api = makeApi({ fetchLatestResults: vi.fn().mockRejectedValue(new Error('boom')) });
    renderDetail(api);
    expect(await screen.findByText(/We couldn't load Jordan's lab results/)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Try again' })).toBeInTheDocument();
    // components.md C35: err variant is status.critical/criticalSubtle with a
    // 20px icon, not a plain neutral card.
    const banner = screen.getByRole('alert');
    expect(banner.className).toMatch(/FCE8E6/);
    expect(banner.querySelector('svg')).toBeInTheDocument();
  });
});
