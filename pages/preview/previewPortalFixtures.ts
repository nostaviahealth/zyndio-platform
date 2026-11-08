import { PatientRecordApi, PrevisitBrief, TimelineEvent, PatientExport } from '../../lib/patientRecordApi';
import { OrgPlan, PlanApi, PlanPeriod, RangeItem, RangeSet, RangesApi, mapPlan } from '../../lib/clinicConfigApi';
import { LatestResult, TrendPoint } from '../../lib/clinicalApi';
import { HBA1C_TREND, JORDAN_LATEST } from './previewClinicalFixtures';

// Fictional fixtures for the POR-03..06 / PP-01 preview states. Same rule as
// previewClinicalFixtures.ts: they feed the REAL page components through
// their API boundaries. Dates sit before DETAIL_NOW (Oct 18, 2026).

const never = <T,>(): Promise<T> => new Promise<T>(() => {});

export const JORDAN_TIMELINE: TimelineEvent[] = [
  {
    occurredAt: '2026-10-14T12:00:00Z', source: 'labs', eventType: 'lab_report', title: 'metabolic_panel', status: 'needs_review', refId: 'r4',
    detail: {
      reportType: 'metabolic_panel', resultCount: 6, outsideCount: 0, needsReviewCount: 1,
      results: JORDAN_LATEST.map((m) => ({
        analyteKey: m.analyteKey, analyteLabel: m.analyteLabel, value: m.value, originalValue: m.originalValue, unit: m.unit,
        status: m.status, rangeLow: m.rangeLow, rangeHigh: m.rangeHigh, rangeSource: 'default' as const,
      })),
    },
  },
  { occurredAt: '2026-10-01T00:00:00Z', source: 'visits', eventType: 'visit', title: 'Visit', status: null, refId: 'v1', detail: { visitOn: '2026-10-01' } },
  {
    occurredAt: '2026-08-06T00:00:00Z', source: 'labs', eventType: 'lab_report', title: 'metabolic_panel', status: 'within_range', refId: 'r3',
    detail: { reportType: 'metabolic_panel', resultCount: 2, outsideCount: 0, needsReviewCount: 0, results: [] },
  },
  {
    occurredAt: '2026-06-04T00:00:00Z', source: 'labs', eventType: 'lab_report', title: 'metabolic_panel', status: 'outside_range', refId: 'r2',
    detail: { reportType: 'metabolic_panel', resultCount: 2, outsideCount: 1, needsReviewCount: 0, results: [] },
  },
  {
    occurredAt: '2026-04-02T00:00:00Z', source: 'treatment', eventType: 'treatment_started', title: 'Example GLP-1 medication (fictional)', status: 'Active',
    refId: 't1', detail: { treatmentStatus: 'Active', treatmentSource: 'Zyndio record, Oct 20, 2026' },
  },
  {
    occurredAt: '2026-04-02T00:00:00Z', source: 'labs', eventType: 'lab_report', title: 'metabolic_panel', status: 'outside_range', refId: 'r1',
    detail: { reportType: 'metabolic_panel', resultCount: 2, outsideCount: 2, needsReviewCount: 0, results: [] },
  },
  { occurredAt: '2026-04-02T00:00:00Z', source: 'program', eventType: 'program_started', title: 'Program started', status: null, refId: 'p-jordan', detail: {} },
];

export const JORDAN_BRIEF: PrevisitBrief = {
  patientId: 'p-jordan',
  generatedAt: '2026-10-18T10:00:00Z',
  since: { date: '2026-10-01', basis: 'last_visit' },
  lastVisitOn: '2026-10-01',
  treatment: { name: 'Example GLP-1 medication (fictional)', status: 'Active', startedOn: '2026-04-02' },
  counts: { resultsSince: 6, markersSince: 6 },
  outOfRange: [],
  changes: [
    { analyteKey: 'hba1c', analyteLabel: 'HbA1c', unit: '%', baselineValue: 6.2, baselineAt: '2026-04-02T00:00:00Z', latestValue: 5.5, latestAt: '2026-10-14T12:00:00Z', delta: -0.7, latestStatus: 'within_range' },
    { analyteKey: 'glucose_fasting', analyteLabel: 'Glucose, fasting', unit: 'mg/dL', baselineValue: 104, baselineAt: '2026-04-02T00:00:00Z', latestValue: 98, latestAt: '2026-10-14T12:00:00Z', delta: -6, latestStatus: 'within_range' },
  ],
  flags: { needsReview: 1, identityHold: false, openQuestions: 1 },
  missing: [{ code: 'marker_not_rechecked', analyteKey: 'lp_pla2', analyteLabel: 'Lp-PLA2', lastAt: '2026-06-04T00:00:00Z' }],
};

const EXPORT_DOC: PatientExport = {
  schemaVersion: 1,
  exportedAt: '2026-10-18T10:00:00Z',
  patient: { patientId: 'p-jordan', displayName: 'Jordan Rivera', mrn: 'ZP-10482', sex: 'female', birthDate: '1985-03-01', programStartedOn: '2026-04-02' },
  treatments: [],
  visits: [],
  labResults: [],
};

export function recordFixtureApi(state: string): PatientRecordApi {
  return {
    fetchTimeline: async () => (state === 'timeline-empty' ? [] : JORDAN_TIMELINE),
    fetchBrief: async () => JORDAN_BRIEF,
    recordVisit: async () => undefined,
    exportRecord: async () => EXPORT_DOC,
  };
}

// 'approved-ranges': the clinic has an approved set covering HbA1c (v2).
export const JORDAN_LATEST_APPROVED: LatestResult[] = JORDAN_LATEST.map((m) =>
  m.analyteKey === 'hba1c' ? { ...m, rangeHigh: 5.6, rangeSource: 'approved', rangeSetVersion: 2 } : m
);
export const HBA1C_TREND_APPROVED: TrendPoint[] = HBA1C_TREND.map((p) => ({
  ...p,
  rangeHigh: 5.6,
  rangeSource: 'approved',
  status: p.value !== null && p.value > 5.6 ? 'outside_range' : 'within_range',
}));

const LIVE: RangeSet = {
  id: 'set-2', version: 2, status: 'approved', note: 'Metabolic panel, physician lead review', itemCount: 4,
  createdByName: 'Dr. Morgan Ellis', createdAt: '2026-10-08T00:00:00Z', approvedByName: 'Dr. Morgan Ellis', approvedAt: '2026-10-09T00:00:00Z', closedAt: null,
};
const OLD: RangeSet = { ...LIVE, id: 'set-1', version: 1, status: 'superseded', note: null, itemCount: 2, approvedAt: '2026-09-02T00:00:00Z', closedAt: '2026-10-09T00:00:00Z' };
const DRAFT: RangeSet = { ...LIVE, id: 'set-3', version: 3, status: 'draft', note: 'Add ApoB', approvedByName: null, approvedAt: null };

const ITEMS: RangeItem[] = [
  { id: 'i1', analyteKey: 'hba1c', analyteLabel: 'HbA1c', sex: 'any', low: null, high: 5.6, unit: '%' },
  { id: 'i2', analyteKey: 'glucose_fasting', analyteLabel: 'Glucose, fasting', sex: 'any', low: 70, high: 99, unit: 'mg/dL' },
  { id: 'i3', analyteKey: 'triglycerides', analyteLabel: 'Triglycerides', sex: 'any', low: null, high: 150, unit: 'mg/dL' },
  { id: 'i4', analyteKey: 'hscrp', analyteLabel: 'hsCRP', sex: 'any', low: null, high: 2, unit: 'mg/L' },
  { id: 'i5', analyteKey: 'apob', analyteLabel: 'ApoB', sex: 'any', low: null, high: 90, unit: 'mg/dL' },
];

export function rangesFixtureApi(state: string): RangesApi {
  const sets = state === 'none' ? [] : state === 'loading' ? null : state === 'draft' ? [DRAFT, LIVE, OLD] : [LIVE, OLD];
  return {
    listRangeSets: async () => (sets === null ? never<RangeSet[]>() : sets),
    fetchRangeItems: async (id) => (id === 'set-3' ? ITEMS : id === 'set-2' ? ITEMS.slice(0, 4) : ITEMS.slice(0, 2)),
    createDraft: async () => 'set-3',
    saveItem: async () => undefined,
    deleteItem: async () => undefined,
    approve: async () => undefined,
    discard: async () => undefined,
  };
}

const PLAN: OrgPlan = mapPlan({
  tier: 'core',
  standard_modules: ['re_test_recall', 'wearables'],
  effective_from: '2026-10-12T00:00:00Z',
  max_standard_modules: 2,
  catalog: [
    { module_key: 'patient_app', label: 'Patient app', kind: 'core', is_placeholder: true },
    { module_key: 'labs_biomarkers', label: 'Labs and biomarkers', kind: 'core', is_placeholder: true },
    { module_key: 'physician_portal', label: 'Physician portal', kind: 'core', is_placeholder: true },
    { module_key: 'treatment_context', label: 'Treatment context', kind: 'core', is_placeholder: true },
    { module_key: 'notifications', label: 'Notifications', kind: 'core', is_placeholder: true },
    { module_key: 'wearables', label: 'Wearables', kind: 'standard', is_placeholder: true },
    { module_key: 'nutrition_logging', label: 'Nutrition logging', kind: 'standard', is_placeholder: true },
    { module_key: 'ai_companion', label: 'AI companion', kind: 'standard', is_placeholder: true },
    { module_key: 'gamification', label: 'Challenges and points', kind: 'standard', is_placeholder: true },
    { module_key: 'integration_api', label: 'Integration API', kind: 'standard', is_placeholder: true },
    { module_key: 're_test_recall', label: 'Re-Test Recall', kind: 'standard', is_placeholder: false },
  ],
});

const HISTORY: PlanPeriod[] = [
  { id: '3', tier: 'core', standardModules: ['re_test_recall', 'wearables'], effectiveFrom: '2026-10-12T00:00:00Z', effectiveTo: null, changedByName: 'Taylor Brooks', reason: 'Added Re-Test Recall' },
  { id: '2', tier: 'core', standardModules: ['wearables'], effectiveFrom: '2026-09-15T00:00:00Z', effectiveTo: '2026-10-12T00:00:00Z', changedByName: 'Taylor Brooks', reason: 'Signed order form' },
  { id: '1', tier: 'core', standardModules: [], effectiveFrom: '2026-09-01T00:00:00Z', effectiveTo: '2026-09-15T00:00:00Z', changedByName: null, reason: null },
];

export function planFixtureApi(): PlanApi {
  return { fetchPlan: async () => PLAN, fetchHistory: async () => HISTORY, setPlan: async () => undefined };
}
