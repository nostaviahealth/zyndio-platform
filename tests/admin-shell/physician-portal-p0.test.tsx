// @vitest-environment jsdom
// POR-03 Timeline, POR-04 Pre-visit brief, POR-05 caveat, POR-06 Export on the
// live PhysicianPatientDetail page (fixture APIs injected at the boundary).
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';

import PhysicianPatientDetail from '../../pages/admin/clinic/PhysicianPatientDetail';
import { ClinicalApi, LatestResult, PatientDetail, TrendPoint } from '../../lib/clinicalApi';
import { PatientExport, PatientRecordApi, PrevisitBrief, TimelineEvent } from '../../lib/patientRecordApi';

const NOW = new Date('2026-10-18T10:00:00Z');

const DETAIL: PatientDetail = {
  patientId: 'p-jordan',
  displayName: 'Jordan Rivera',
  mrn: 'ZP-10482',
  sex: 'female',
  birthDate: '1985-03-01',
  programStartedOn: '2026-04-02T00:00:00Z',
  lastActivityAt: '2026-10-18T09:12:00Z',
  treatment: { name: 'Example GLP-1 medication (fictional)', startedOn: '2026-04-02', status: 'Active', source: 'Fictional record' },
};

const HBA1C: LatestResult = {
  analyteKey: 'hba1c', analyteLabel: 'HbA1c', value: 5.5, originalValue: null, unit: '%', status: 'within_range',
  isUnmapped: false, rangeLow: null, rangeHigh: 5.7, takenAt: '2026-10-14T12:00:00Z', rangeSource: 'default',
};
const TREND: TrendPoint[] = [
  { takenAt: '2026-04-02T00:00:00Z', value: 6.2, originalValue: null, unit: '%', status: 'baseline', rangeLow: null, rangeHigh: 5.7 },
  { takenAt: '2026-10-14T12:00:00Z', value: 5.5, originalValue: null, unit: '%', status: 'within_range', rangeLow: null, rangeHigh: 5.7 },
];

const TIMELINE: TimelineEvent[] = [
  {
    occurredAt: '2026-10-14T12:00:00Z', source: 'labs', eventType: 'lab_report', title: 'metabolic_panel', status: 'outside_range',
    refId: 'r1',
    detail: {
      reportType: 'metabolic_panel', resultCount: 2, outsideCount: 1, needsReviewCount: 0,
      results: [
        { analyteKey: 'glucose_fasting', analyteLabel: 'Glucose, fasting', value: 104, originalValue: null, unit: 'mg/dL', status: 'outside_range', rangeLow: 70, rangeHigh: 99, rangeSource: 'default' },
        { analyteKey: 'hba1c', analyteLabel: 'HbA1c', value: 5.5, originalValue: 5.8, unit: '%', status: 'within_range', rangeLow: null, rangeHigh: 5.7, rangeSource: 'approved' },
      ],
    },
  },
  {
    occurredAt: '2026-04-02T00:00:00Z', source: 'treatment', eventType: 'treatment_started', title: 'Example GLP-1 medication (fictional)',
    status: 'Active', refId: 't1', detail: { treatmentStatus: 'Active', treatmentSource: 'Fictional record' },
  },
  { occurredAt: '2026-04-01T00:00:00Z', source: 'wearables', eventType: 'wearable_day', title: 'Wearable summary', status: null, refId: 'w1', detail: {} },
];

const BRIEF: PrevisitBrief = {
  patientId: 'p-jordan',
  generatedAt: '2026-10-18T10:00:00Z',
  since: { date: '2026-10-01', basis: 'last_visit' },
  lastVisitOn: '2026-10-01',
  treatment: { name: 'Example GLP-1 medication (fictional)', status: 'Active', startedOn: '2026-04-02' },
  counts: { resultsSince: 2, markersSince: 2 },
  outOfRange: [
    { analyteKey: 'glucose_fasting', analyteLabel: 'Glucose, fasting', value: 104, unit: 'mg/dL', takenAt: '2026-10-14T12:00:00Z', rangeLow: 70, rangeHigh: 99, rangeSource: 'default' },
  ],
  changes: [
    { analyteKey: 'hba1c', analyteLabel: 'HbA1c', unit: '%', baselineValue: 6.2, baselineAt: '2026-04-02T00:00:00Z', latestValue: 5.5, latestAt: '2026-10-14T12:00:00Z', delta: -0.7000000000000002, latestStatus: 'within_range' },
  ],
  flags: { needsReview: 1, identityHold: false, openQuestions: 1 },
  missing: [{ code: 'marker_not_rechecked', analyteKey: 'apob', analyteLabel: 'ApoB', lastAt: '2026-04-02T00:00:00Z' }],
};

const EXPORT_DOC: PatientExport = {
  schemaVersion: 1,
  exportedAt: '2026-10-18T10:00:00Z',
  patient: { patientId: 'p-jordan', displayName: 'Jordan Rivera', mrn: 'ZP-10482', sex: 'female', birthDate: '1985-03-01', programStartedOn: '2026-04-02' },
  treatments: [],
  visits: [],
  labResults: [],
};

function makeApi(over: Partial<ClinicalApi> = {}): ClinicalApi {
  return {
    fetchRoster: vi.fn(),
    fetchChipCounts: vi.fn(),
    openPatientDetail: vi.fn().mockResolvedValue(DETAIL),
    fetchLatestResults: vi.fn().mockResolvedValue([HBA1C]),
    fetchTrend: vi.fn().mockResolvedValue(TREND),
    ...over,
  };
}

function makeRecordApi(over: Partial<PatientRecordApi> = {}): PatientRecordApi {
  return {
    fetchTimeline: vi.fn().mockResolvedValue(TIMELINE),
    fetchBrief: vi.fn().mockResolvedValue(BRIEF),
    recordVisit: vi.fn().mockResolvedValue(undefined),
    exportRecord: vi.fn().mockResolvedValue(EXPORT_DOC),
    ...over,
  };
}

function renderDetail(props: Partial<React.ComponentProps<typeof PhysicianPatientDetail>> = {}) {
  return render(
    <MemoryRouter>
      <PhysicianPatientDetail api={makeApi()} recordApi={makeRecordApi()} now={NOW} patientId="p-jordan" {...props} />
    </MemoryRouter>
  );
}

describe('POR-03 Timeline tab', () => {
  it('loads the timeline only when opened, newest first, with labels and an expandable lab report', async () => {
    const user = userEvent.setup();
    const recordApi = makeRecordApi();
    renderDetail({ recordApi, viewerRole: 'physician' });
    await screen.findByRole('heading', { name: 'Jordan Rivera' });
    expect(recordApi.fetchTimeline).not.toHaveBeenCalled();

    await user.click(screen.getByRole('tab', { name: 'Timeline' }));
    expect(screen.getByRole('tab', { name: 'Timeline' })).toHaveAttribute('aria-selected', 'true');
    const list = await screen.findByRole('list', { name: 'Timeline for Jordan Rivera' });
    const items = within(list).getAllByRole('listitem');
    expect(items).toHaveLength(3);
    expect(items[0]).toHaveTextContent('Oct 14, 2026');
    expect(items[0]).toHaveTextContent('Metabolic panel');
    expect(items[0]).toHaveTextContent('2 results · 1 outside range');
    expect(within(items[0]).getByText('Outside range')).toBeInTheDocument();
    expect(items[1]).toHaveTextContent('Example GLP-1 medication (fictional) started');
    // A source the UI doesn't know yet still renders (extension point).
    expect(items[2]).toHaveTextContent('Other');
    expect(items[2]).toHaveTextContent('Wearable summary');

    const toggle = within(items[0]).getByRole('button', { name: /Metabolic panel/ });
    expect(toggle).toHaveAttribute('aria-expanded', 'false');
    await user.click(toggle);
    expect(toggle).toHaveAttribute('aria-expanded', 'true');
    expect(within(items[0]).getByText('Glucose, fasting')).toBeInTheDocument();
    expect(within(items[0]).getByText('was 5.8')).toBeInTheDocument();
    expect(within(items[0]).getByText('Within clinic range')).toBeInTheDocument();
    expect(document.body.textContent).not.toMatch(/dose/i);
  });

  it('empty and error states (error retries)', async () => {
    const user = userEvent.setup();
    const fetchTimeline = vi.fn().mockRejectedValueOnce(new Error('x')).mockResolvedValueOnce([]);
    renderDetail({ recordApi: makeRecordApi({ fetchTimeline }), initialTab: 'timeline' });
    expect(await screen.findByText(/We couldn't load Jordan's timeline/)).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await screen.findByText('Nothing on the timeline yet')).toBeInTheDocument();
    expect(fetchTimeline).toHaveBeenCalledTimes(2);
  });

  it('arrow keys move between the live tabs', async () => {
    const user = userEvent.setup();
    renderDetail();
    await screen.findByRole('heading', { name: 'Jordan Rivera' });
    screen.getByRole('tab', { name: 'Labs' }).focus();
    await user.keyboard('{ArrowRight}');
    expect(screen.getByRole('tab', { name: 'Timeline' })).toHaveFocus();
    expect(screen.getByRole('tab', { name: 'Timeline' })).toHaveAttribute('aria-selected', 'true');
    await user.keyboard('{ArrowRight}');
    expect(screen.getByRole('tab', { name: 'Pre-visit brief' })).toHaveAttribute('aria-selected', 'true');
    await user.keyboard('{ArrowRight}');
    expect(screen.getByRole('tab', { name: 'Treatment' })).toHaveAttribute('aria-selected', 'true');
    await user.keyboard('{ArrowRight}');
    expect(screen.getByRole('tab', { name: 'Labs' })).toHaveAttribute('aria-selected', 'true');
  });
});

describe('POR-04 Pre-visit brief tab', () => {
  it('renders the fixed-template sections and the no-AI footer', async () => {
    renderDetail({ initialTab: 'brief', viewerRole: 'physician' });
    expect(await screen.findByText('Since the last visit on Oct 1, 2026')).toBeInTheDocument();
    expect(screen.getByText('2 lab results across 2 markers in this period.')).toBeInTheDocument();
    expect(screen.getByText('Treatment: Example GLP-1 medication (fictional) · Active · started Apr 2, 2026')).toBeInTheDocument();
    const outSection = screen.getByRole('region', { name: 'Latest results outside range' });
    expect(outSection).toHaveTextContent('Glucose, fasting: 104 mg/dL on Oct 14, 2026, outside the default range 70–99 mg/dL.');
    expect(screen.getByRole('region', { name: 'Changes since baseline' })).toHaveTextContent(
      'HbA1c: 6.2 → 5.5 % (−0.7), Apr 2, 2026 to Oct 14, 2026.'
    );
    const flags = screen.getByRole('region', { name: 'Open flags' });
    expect(flags).toHaveTextContent('1 marker needs checking against the report.');
    expect(flags).toHaveTextContent('1 open question from the patient.');
    expect(screen.getByRole('region', { name: 'Missing data' })).toHaveTextContent(
      'ApoB not rechecked since the last visit (last result Apr 2, 2026).'
    );
    expect(screen.getByText(/No AI-written text\./)).toBeInTheDocument();
  });

  it('physician can mark a visit done today, which reloads the brief', async () => {
    const user = userEvent.setup();
    const recordApi = makeRecordApi();
    renderDetail({ recordApi, initialTab: 'brief', viewerRole: 'physician' });
    await user.click(await screen.findByRole('button', { name: 'Mark visit done today' }));
    expect(recordApi.recordVisit).toHaveBeenCalledWith('p-jordan', null);
    await waitFor(() => expect(recordApi.fetchBrief).toHaveBeenCalledTimes(2));
  });

  it('read_only sees the brief but no "mark visit" action', async () => {
    renderDetail({ initialTab: 'brief', viewerRole: 'read_only' });
    expect(await screen.findByText('Since the last visit on Oct 1, 2026')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Mark visit done today' })).not.toBeInTheDocument();
  });

  it('a failed brief shows the error banner, not a partial brief', async () => {
    renderDetail({ initialTab: 'brief', recordApi: makeRecordApi({ fetchBrief: vi.fn().mockRejectedValue(new Error('x')) }) });
    expect(await screen.findByText(/We couldn't build Jordan's pre-visit brief/)).toBeInTheDocument();
    expect(screen.queryByRole('region', { name: 'Open flags' })).not.toBeInTheDocument();
  });
});

describe('POR-06 Export', () => {
  it.each(['physician', 'care_coordinator'])('%s can export JSON and CSV through the server', async (role) => {
    const user = userEvent.setup();
    const recordApi = makeRecordApi();
    const onDownload = vi.fn();
    renderDetail({ recordApi, viewerRole: role, onDownload });
    await screen.findByRole('heading', { name: 'Jordan Rivera' });

    await user.click(screen.getByRole('button', { name: 'Export data' }));
    await user.click(screen.getByRole('menuitem', { name: /JSON/ }));
    await waitFor(() => expect(onDownload).toHaveBeenCalledWith(EXPORT_DOC, 'json'));
    expect(recordApi.exportRecord).toHaveBeenCalledWith('p-jordan', 'json');

    await user.click(screen.getByRole('button', { name: 'Export data' }));
    await user.click(screen.getByRole('menuitem', { name: /CSV/ }));
    await waitFor(() => expect(onDownload).toHaveBeenCalledWith(EXPORT_DOC, 'csv'));
  });

  it('a refused or failed export downloads nothing and says so', async () => {
    const user = userEvent.setup();
    const onDownload = vi.fn();
    renderDetail({
      viewerRole: 'physician',
      onDownload,
      recordApi: makeRecordApi({ exportRecord: vi.fn().mockRejectedValue(Object.assign(new Error('denied'), { code: '42501' })) }),
    });
    await screen.findByRole('heading', { name: 'Jordan Rivera' });
    await user.click(screen.getByRole('button', { name: 'Export data' }));
    await user.click(screen.getByRole('menuitem', { name: /CSV/ }));
    expect(await screen.findByText(/We couldn't export this record. Nothing was downloaded./)).toBeInTheDocument();
    expect(onDownload).not.toHaveBeenCalled();
  });

  it.each([['read_only'], ['org_admin'], [undefined]])('role %s: Export is blocked in the UI and never calls the server', async (role) => {
    const user = userEvent.setup();
    const recordApi = makeRecordApi();
    renderDetail({ recordApi, viewerRole: role });
    await screen.findByRole('heading', { name: 'Jordan Rivera' });
    const btn = screen.getByRole('button', { name: /Export data/ });
    expect(btn).toHaveAttribute('aria-disabled', 'true');
    await user.click(btn);
    expect(screen.queryByRole('menu')).not.toBeInTheDocument();
    expect(recordApi.exportRecord).not.toHaveBeenCalled();
  });
});

describe('POR-05 default-range caveat', () => {
  it('shows the caveat while the marker uses the default range', async () => {
    renderDetail();
    expect(await screen.findByText(/General default range, for demo use only/)).toBeInTheDocument();
    expect(screen.getAllByText('Within default range').length).toBeGreaterThan(0);
  });

  it('hides the caveat once the clinic-approved set covers the marker', async () => {
    renderDetail({
      api: makeApi({ fetchLatestResults: vi.fn().mockResolvedValue([{ ...HBA1C, rangeSource: 'approved', rangeSetVersion: 2 }]) }),
    });
    expect(await screen.findByText(/physician-approved range set/)).toBeInTheDocument();
    expect(screen.getByText(/\(version 2\)/)).toBeInTheDocument();
    expect(screen.queryByText(/General default range, for demo use only/)).not.toBeInTheDocument();
    expect(screen.getAllByText('Within clinic range').length).toBeGreaterThan(0);
  });
});
