import {
  ChipCounts,
  ClinicalApi,
  LatestResult,
  PatientDetail,
  RosterPatient,
  RosterResult,
  TrendPoint,
} from '../../lib/clinicalApi';
import { ReviewDetail } from '../admin/clinic/PhysicianPatientDetail';

// Fictional fixture data for the /__preview harness, built from
// copy-deck.md (01-patient-list, 02-patient-detail). These feed the REAL page
// components through the ClinicalApi boundary - no look-alike markup. Dates
// are chosen so a fixed fixture "now" reproduces the copy-deck's computed age
// / program week / "Today" strings exactly (see lib/clinicalFormat).

// Roster + default detail render against this clock; the single-result detail
// uses its own (a 2-week-old program).
export const ROSTER_NOW = new Date('2026-10-18T10:00:00Z');
export const DETAIL_NOW = new Date('2026-10-18T10:00:00Z');
export const SINGLE_NOW = new Date('2026-10-26T10:00:00Z');

const never = <T,>(): Promise<T> => new Promise<T>(() => {});

export const CHIP_COUNTS: ChipCounts = { all: 42, flagged: 6, missingLabs: 9, questionsWaiting: 3 };

export const ROSTER_ROWS: RosterPatient[] = [
  {
    patientId: 'p-jordan', displayName: 'Jordan Rivera', mrn: 'ZP-10482', sex: 'female',
    birthDate: '1985-03-01', programStartedOn: '2026-04-02T00:00:00Z', latestLabAt: '2026-10-14T12:00:00Z',
    lastActivityAt: '2026-10-18T09:12:00Z', openQuestions: 1, flags: ['question_waiting'],
  },
  {
    patientId: 'p-avery', displayName: 'Avery Thompson', mrn: 'ZP-10517', sex: 'male',
    birthDate: '1970-01-15', programStartedOn: '2026-08-16T00:00:00Z', latestLabAt: '2026-10-20T12:00:00Z',
    lastActivityAt: '2026-10-18T08:05:00Z', openQuestions: 0, flags: ['clinical_context', 'needs_review'],
  },
  {
    patientId: 'p-casey', displayName: 'Casey Lindqvist', mrn: 'ZP-10533', sex: 'female',
    birthDate: '1988-06-10', programStartedOn: '2026-09-20T00:00:00Z', latestLabAt: null,
    lastActivityAt: '2026-10-24T12:00:00Z', openQuestions: 0, flags: ['missing_labs'],
  },
  {
    patientId: 'p-devon', displayName: 'Devon Park', mrn: 'ZP-10541', sex: 'male',
    birthDate: '1977-02-20', programStartedOn: '2026-06-28T00:00:00Z', latestLabAt: '2026-10-02T12:00:00Z',
    lastActivityAt: '2026-10-23T12:00:00Z', openQuestions: 0, flags: ['outside_range'],
  },
  {
    patientId: 'p-harper', displayName: 'Harper Nguyen', mrn: 'ZP-10558', sex: 'female',
    birthDate: '1964-05-05', programStartedOn: '2026-05-17T00:00:00Z', latestLabAt: '2026-09-28T12:00:00Z',
    lastActivityAt: '2026-10-22T12:00:00Z', openQuestions: 0, flags: ['identity_hold'],
  },
  {
    patientId: 'p-rowan', displayName: 'Rowan Castillo', mrn: 'ZP-10560', sex: 'male',
    birthDate: '1981-08-12', programStartedOn: '2026-07-26T00:00:00Z', latestLabAt: '2026-10-18T12:00:00Z',
    lastActivityAt: '2026-10-21T12:00:00Z', openQuestions: 0, flags: [],
  },
  {
    patientId: 'p-quinn', displayName: 'Quinn Adeyemi', mrn: 'ZP-10572', sex: 'female',
    birthDate: '1975-03-03', programStartedOn: '2026-03-22T00:00:00Z', latestLabAt: '2026-10-09T12:00:00Z',
    lastActivityAt: '2026-10-20T12:00:00Z', openQuestions: 1, flags: ['outside_range', 'question_waiting'],
  },
  {
    patientId: 'p-skyler', displayName: 'Skyler Moreau', mrn: 'ZP-10589', sex: 'male',
    birthDate: '1992-09-01', programStartedOn: '2026-10-04T00:00:00Z', latestLabAt: null,
    lastActivityAt: '2026-10-19T12:00:00Z', openQuestions: 0, flags: ['missing_labs'],
  },
];

// Questions-waiting filter, oldest question first: Quinn then Jordan (of 3).
export const FILTERED_ROWS: RosterPatient[] = [ROSTER_ROWS[6], ROSTER_ROWS[0]];

export const JORDAN_DETAIL: PatientDetail = {
  patientId: 'p-jordan', displayName: 'Jordan Rivera', mrn: 'ZP-10482', sex: 'female',
  birthDate: '1985-03-01', programStartedOn: '2026-04-02T00:00:00Z', lastActivityAt: '2026-10-18T09:12:00Z',
  treatment: {
    name: 'Example GLP-1 medication (fictional)', startedOn: '2026-04-02T00:00:00Z', status: 'Active',
    source: 'Zyndio record, Oct 20, 2026',
  },
};

export const JORDAN_SINGLE_DETAIL: PatientDetail = {
  ...JORDAN_DETAIL,
  programStartedOn: '2026-10-12T00:00:00Z',
  treatment: { ...JORDAN_DETAIL.treatment!, startedOn: '2026-10-12T00:00:00Z' },
};

export const JORDAN_LATEST: LatestResult[] = [
  { analyteKey: 'hba1c', analyteLabel: 'HbA1c', value: 5.5, originalValue: null, unit: '%', status: 'within_range', isUnmapped: false, rangeLow: null, rangeHigh: 5.7, takenAt: '2026-10-14T12:00:00Z' },
  { analyteKey: 'glucose_fasting', analyteLabel: 'Glucose, fasting', value: 98, originalValue: null, unit: 'mg/dL', status: 'within_range', isUnmapped: false, rangeLow: 70, rangeHigh: 99, takenAt: '2026-10-14T12:00:00Z' },
  { analyteKey: 'insulin_fasting', analyteLabel: 'Insulin, fasting', value: 9.4, originalValue: null, unit: 'uIU/mL', status: 'no_range', isUnmapped: false, rangeLow: null, rangeHigh: null, takenAt: '2026-10-14T12:00:00Z' },
  { analyteKey: 'apob', analyteLabel: 'ApoB', value: 84, originalValue: null, unit: 'mg/dL', status: 'no_range', isUnmapped: false, rangeLow: null, rangeHigh: null, takenAt: '2026-10-14T12:00:00Z' },
  { analyteKey: 'hscrp', analyteLabel: 'hsCRP', value: 1.7, originalValue: null, unit: 'mg/L', status: 'needs_review', isUnmapped: false, rangeLow: null, rangeHigh: null, takenAt: '2026-10-14T12:00:00Z' },
  { analyteKey: 'triglycerides', analyteLabel: 'Triglycerides', value: 121, originalValue: null, unit: 'mg/dL', status: 'no_range', isUnmapped: false, rangeLow: null, rangeHigh: null, takenAt: '2026-10-14T12:00:00Z' },
];

export const JORDAN_SINGLE_LATEST: LatestResult[] = [
  { analyteKey: 'hba1c', analyteLabel: 'HbA1c', value: 6.2, originalValue: null, unit: '%', status: 'baseline', isUnmapped: false, rangeLow: null, rangeHigh: 5.7, takenAt: '2026-10-14T12:00:00Z' },
  { analyteKey: 'glucose_fasting', analyteLabel: 'Glucose, fasting', value: 104, originalValue: null, unit: 'mg/dL', status: 'baseline', isUnmapped: false, rangeLow: 70, rangeHigh: 99, takenAt: '2026-10-14T12:00:00Z' },
];

export const HBA1C_TREND: TrendPoint[] = [
  { takenAt: '2026-04-02T00:00:00Z', value: 6.2, originalValue: null, unit: '%', status: 'baseline', rangeLow: null, rangeHigh: 5.7 },
  { takenAt: '2026-06-04T00:00:00Z', value: 5.9, originalValue: null, unit: '%', status: 'within_range', rangeLow: null, rangeHigh: 5.7 },
  { takenAt: '2026-08-06T00:00:00Z', value: 5.7, originalValue: null, unit: '%', status: 'within_range', rangeLow: null, rangeHigh: 5.7 },
  { takenAt: '2026-10-14T12:00:00Z', value: 5.5, originalValue: null, unit: '%', status: 'within_range', rangeLow: null, rangeHigh: 5.7 },
];

export const HBA1C_SINGLE_TREND: TrendPoint[] = [HBA1C_TREND[3] && { ...HBA1C_TREND[0], takenAt: '2026-10-14T12:00:00Z' }].filter(Boolean) as TrendPoint[];

export const HSCRP_REVIEW_DETAILS: Record<string, ReviewDetail> = {
  hscrp: {
    provenance: 'read from page 2 of the report',
    printed: '1.7 mg/L (smudged)',
    confidence: 'Low',
    report: 'Metabolic panel, Fictional Reference Lab',
  },
};

const notUsed = () => {
  throw new Error('not used in this preview state');
};

export function rosterFixtureApi(state: string): ClinicalApi {
  const counts = async () => CHIP_COUNTS;
  let fetchRoster: ClinicalApi['fetchRoster'];
  switch (state) {
    case 'loading':
      fetchRoster = () => never<RosterResult>();
      break;
    case 'empty':
      return {
        fetchRoster: async () => ({ rows: [], totalCount: 0 }),
        fetchChipCounts: async () => ({ all: 0, flagged: 0, missingLabs: 0, questionsWaiting: 0 }),
        openPatientDetail: notUsed, fetchLatestResults: notUsed, fetchTrend: notUsed,
      };
    case 'no-results':
      fetchRoster = async () => ({ rows: [], totalCount: 0 });
      break;
    case 'filtered':
      fetchRoster = async () => ({ rows: FILTERED_ROWS, totalCount: 3 });
      break;
    case 'error':
      fetchRoster = async () => {
        throw new Error('fixture error');
      };
      break;
    default:
      fetchRoster = async () => ({ rows: ROSTER_ROWS, totalCount: 42 });
  }
  return { fetchRoster, fetchChipCounts: counts, openPatientDetail: notUsed, fetchLatestResults: notUsed, fetchTrend: notUsed };
}

export function detailFixtureApi(state: string): ClinicalApi {
  const base: ClinicalApi = {
    fetchRoster: notUsed,
    fetchChipCounts: notUsed,
    openPatientDetail: async () => JORDAN_DETAIL,
    fetchLatestResults: async () => JORDAN_LATEST,
    fetchTrend: async () => HBA1C_TREND,
  };
  switch (state) {
    case 'loading':
      return { ...base, fetchLatestResults: () => never<LatestResult[]>() };
    case 'empty':
      return { ...base, fetchLatestResults: async () => [] };
    case 'single':
      return {
        ...base,
        openPatientDetail: async () => JORDAN_SINGLE_DETAIL,
        fetchLatestResults: async () => JORDAN_SINGLE_LATEST,
        fetchTrend: async () => HBA1C_SINGLE_TREND,
      };
    case 'needs-review':
      return base;
    case 'error':
      return {
        ...base,
        fetchLatestResults: async () => {
          throw new Error('fixture error');
        },
      };
    case 'not-found':
      return { ...base, openPatientDetail: async () => null };
    default:
      return base;
  }
}
