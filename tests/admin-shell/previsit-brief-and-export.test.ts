import { describe, it, expect, vi, beforeEach } from 'vitest';

const rpc = vi.fn();
vi.mock('../../lib/supabase', () => ({
  supabase: { rpc: (...args: unknown[]) => rpc(...args) },
}));

import {
  briefSections,
  changeLine,
  missingLine,
  outOfRangeLine,
  rangePhrase,
  sinceLine,
  summaryLine,
} from '../../lib/previsitBrief';
import { csvCell, exportFileName, toCsv, CSV_COLUMNS } from '../../lib/patientExport';
import {
  exportRecord,
  fetchBrief,
  fetchTimeline,
  mapBrief,
  mapExport,
  mapTimelineEvent,
  PrevisitBrief,
  recordVisit,
} from '../../lib/patientRecordApi';
import { statusLabel, rangeLegendText } from '../../lib/clinicalFormat';

beforeEach(() => rpc.mockReset());

const BASE: PrevisitBrief = {
  patientId: 'p1',
  generatedAt: '2026-10-18T10:00:00Z',
  since: { date: '2026-04-02', basis: 'program_start' },
  lastVisitOn: null,
  treatment: null,
  counts: { resultsSince: 0, markersSince: 0 },
  outOfRange: [],
  changes: [],
  flags: { needsReview: 0, identityHold: false, openQuestions: 0 },
  missing: [],
};

describe('POR-04 brief templates (fixed wording)', () => {
  it('since line per basis', () => {
    expect(sinceLine(BASE)).toBe('Since the program started on Apr 2, 2026 (no visit recorded yet)');
    expect(sinceLine({ ...BASE, since: { date: '2026-10-01', basis: 'last_visit' } })).toBe('Since the last visit on Oct 1, 2026');
    expect(sinceLine({ ...BASE, since: { date: '2026-05-01', basis: 'first_result' } })).toBe(
      'Since the first lab result on May 1, 2026 (no visit recorded yet)'
    );
    expect(sinceLine({ ...BASE, since: { date: null, basis: 'none' } })).toBe('No visit, program start or lab result on record yet');
  });

  it('summary line pluralises and handles zero', () => {
    expect(summaryLine(BASE)).toBe('No new lab results in this period.');
    expect(summaryLine({ ...BASE, counts: { resultsSince: 1, markersSince: 1 } })).toBe('1 lab result across 1 marker in this period.');
    expect(summaryLine({ ...BASE, since: { date: null, basis: 'none' } })).toBe('No lab results on record.');
  });

  it('range phrases', () => {
    expect(rangePhrase(70, 99, 'mg/dL')).toBe('range 70–99 mg/dL');
    expect(rangePhrase(null, 5.7, '%')).toBe('range up to 5.7 %');
    expect(rangePhrase(40, null, 'mg/dL')).toBe('range from 40 mg/dL');
    expect(rangePhrase(null, null, null)).toBe('no range set');
  });

  it('out-of-range line names the range source', () => {
    const m = { analyteKey: 'hba1c', analyteLabel: 'HbA1c', value: 5.6, unit: '%', takenAt: '2026-10-14T12:00:00Z', rangeLow: null, rangeHigh: 5.5 };
    expect(outOfRangeLine({ ...m, rangeSource: 'approved' })).toBe('HbA1c: 5.6 % on Oct 14, 2026, outside the clinic range up to 5.5 %.');
    expect(outOfRangeLine({ ...m, rangeSource: 'default' })).toBe('HbA1c: 5.6 % on Oct 14, 2026, outside the default range up to 5.5 %.');
  });

  it('change line rounds only the difference (no float noise) and signs it', () => {
    const c = {
      analyteKey: 'hba1c', analyteLabel: 'HbA1c', unit: '%', baselineValue: 6.4, baselineAt: '2026-04-02T00:00:00Z',
      latestValue: 5.6, latestAt: '2026-10-14T00:00:00Z', delta: -0.8000000000000007, latestStatus: 'within_range' as const,
    };
    expect(changeLine(c)).toBe('HbA1c: 6.4 → 5.6 % (−0.8), Apr 2, 2026 to Oct 14, 2026.');
    expect(changeLine({ ...c, baselineValue: 90, latestValue: 104, delta: 14, unit: 'mg/dL' })).toContain('(+14)');
    expect(changeLine({ ...c, latestValue: 6.4, delta: 0 })).toContain('(no change)');
  });

  it('missing-data codes', () => {
    expect(missingLine({ code: 'no_labs' })).toBe('No lab results on record.');
    expect(missingLine({ code: 'no_labs_since_visit', since: '2026-10-01' })).toBe('No lab results since the last visit.');
    expect(missingLine({ code: 'labs_stale', latestAt: '2026-06-01T00:00:00Z', days: 139 })).toBe(
      'Latest lab result is 139 days old (Jun 1, 2026).'
    );
    expect(missingLine({ code: 'no_treatment' })).toBe('No treatment on record.');
  });

  it('every section has fixed empty-state wording', () => {
    const s = briefSections(BASE);
    expect(s.map((x) => x.heading)).toEqual(['Latest results outside range', 'Changes since baseline', 'Open flags', 'Missing data']);
    expect(s.every((x) => x.lines.length === 0 && x.empty.length > 0)).toBe(true);
    const flags = briefSections({ ...BASE, flags: { needsReview: 2, identityHold: true, openQuestions: 3 } })[2];
    expect(flags.lines).toEqual([
      '2 markers need checking against the report.',
      'A lab report is on identity hold until the patient confirms it is theirs.',
      '3 open questions from the patient.',
    ]);
  });
});

describe('POR-04/POR-03 mappers are whitelists', () => {
  it('mapBrief drops unknown missing codes and never carries unknown keys', () => {
    const b = mapBrief({
      patient_id: 'p1',
      since: { date: '2026-10-01', basis: 'last_visit' },
      counts: { results_since: 1, markers_since: 1 },
      out_of_range: [],
      changes: [],
      flags: { needs_review: 0, identity_hold: false, open_questions: 0 },
      missing: [{ code: 'no_treatment' }, { code: 'free_text', text: 'An AI wrote this' }],
      treatment: { name: 'X', status: 'Active', started_on: '2026-04-02', dose: '2.4 mg' },
      summary_text: 'An AI wrote this too',
    })!;
    expect(b.missing).toEqual([{ code: 'no_treatment' }]);
    expect(JSON.stringify(b)).not.toMatch(/AI wrote|dose|2\.4 mg/);
  });

  it('mapBrief returns null for the not-found payload', () => {
    expect(mapBrief(null)).toBeNull();
    expect(mapBrief({})).toBeNull();
  });

  it('mapTimelineEvent keeps only known detail keys', () => {
    const e = mapTimelineEvent({
      occurred_at: '2026-04-02T00:00:00Z', source: 'treatment', event_type: 'treatment_started', title: 'X',
      status: 'Active', ref_id: 't1', detail: { name: 'X', status: 'Active', source: 'S', dose: '2.4 mg weekly' },
    });
    expect(e.detail).toEqual({ treatmentStatus: 'Active', treatmentSource: 'S' });
    expect(JSON.stringify(e)).not.toMatch(/dose/);
  });

  it('mapExport whitelists treatment columns (never a dose)', () => {
    const doc = mapExport({
      schema_version: 1,
      patient: { patient_id: 'p1', display_name: 'Jordan Rivera', mrn: 'ZP-10482' },
      treatments: [{ name: 'X', started_on: '2026-04-02', status: 'Active', source: 'S', dose: '2.4 mg weekly' }],
      visits: [],
      lab_results: [],
    })!;
    expect(Object.keys(doc.treatments[0]).sort()).toEqual(['name', 'source', 'startedOn', 'status']);
    expect(JSON.stringify(doc)).not.toMatch(/dose|2\.4 mg/);
  });

  it('calls the right RPCs with the right arguments', async () => {
    rpc.mockResolvedValue({ data: [], error: null });
    await fetchTimeline('p1', '2026-10-01T00:00:00Z', 50);
    expect(rpc).toHaveBeenLastCalledWith('patient_timeline', { p_patient_id: 'p1', p_before: '2026-10-01T00:00:00Z', p_limit: 50 });
    rpc.mockResolvedValue({ data: null, error: null });
    await fetchBrief('p1');
    expect(rpc).toHaveBeenLastCalledWith('patient_previsit_brief', { p_patient_id: 'p1' });
    await recordVisit('p1');
    expect(rpc).toHaveBeenLastCalledWith('record_patient_visit', { p_patient_id: 'p1', p_visit_on: null });
    await exportRecord('p1', 'csv');
    expect(rpc).toHaveBeenLastCalledWith('export_patient_record', { p_patient_id: 'p1', p_format: 'csv' });
  });

  it('a refused export surfaces the error (no silent empty file)', async () => {
    rpc.mockResolvedValue({ data: null, error: { code: '42501', message: 'not authorized to export patient records' } });
    await expect(exportRecord('p1', 'json')).rejects.toMatchObject({ code: '42501' });
  });
});

describe('POR-06 CSV', () => {
  it('quotes per RFC 4180 and defuses spreadsheet formulas, but keeps negative numbers numeric', () => {
    expect(csvCell('plain')).toBe('plain');
    expect(csvCell('a,b')).toBe('"a,b"');
    expect(csvCell('say "hi"')).toBe('"say ""hi"""');
    expect(csvCell('line\nbreak')).toBe('"line\nbreak"');
    expect(csvCell('=HYPERLINK("x")')).toBe(`"'=HYPERLINK(""x"")"`);
    expect(csvCell('+1')).toBe("'+1");
    expect(csvCell('-2')).toBe("'-2");
    expect(csvCell('@SUM(A1)')).toBe("'@SUM(A1)");
    expect(csvCell(-0.8)).toBe('-0.8');
    expect(csvCell(null)).toBe('');
  });

  it('one flat table: header, patient, treatment, visit and lab rows', () => {
    const csv = toCsv({
      schemaVersion: 1,
      exportedAt: null,
      patient: { patientId: 'p1', displayName: 'Jordan Rivera', mrn: 'ZP-10482', sex: 'female', birthDate: null, programStartedOn: '2026-04-02' },
      treatments: [{ name: 'Example GLP-1 medication (fictional)', startedOn: '2026-04-02', status: 'Active', source: 'Fictional record' }],
      visits: [{ visitOn: '2026-10-01' }],
      labResults: [
        {
          takenAt: '2026-10-14T12:00:00Z', analyteKey: 'hba1c', analyteLabel: 'HbA1c', value: 5.6, originalValue: null, unit: '%',
          status: 'outside_range', rangeLow: null, rangeHigh: 5.5, rangeSource: 'approved', rangeSetVersion: 2, labReportId: 'r1',
        },
      ],
    });
    const lines = csv.trimEnd().split('\r\n');
    expect(lines[0]).toBe(CSV_COLUMNS.join(','));
    expect(lines).toHaveLength(5);
    expect(lines[1]).toBe('patient,2026-04-02,Jordan Rivera,ZP-10482,,,,,,,,,female');
    expect(lines[2]).toBe('treatment,2026-04-02,Example GLP-1 medication (fictional),,,,,Active,,,,,Fictional record');
    expect(lines[3]).toBe('visit,2026-10-01,Visit,,,,,,,,,,');
    expect(lines[4]).toBe('lab_result,2026-10-14T12:00:00Z,HbA1c,hba1c,5.6,,%,outside_range,,5.5,approved,2,');
    expect(lines.every((l) => l.split(',').length >= CSV_COLUMNS.length)).toBe(true);
  });

  it('file name uses a sanitised MRN and the date', () => {
    const doc = { patient: { mrn: 'ZP/10 482' } } as never;
    expect(exportFileName(doc, 'csv', new Date('2026-11-04T10:00:00Z'))).toBe('zyndio-export-ZP10482-2026-11-04.csv');
  });
});

describe('POR-05 range wording', () => {
  it('"Within clinic range" only for approved ranges; legend prefix follows the source', () => {
    expect(statusLabel('within_range', 'approved')).toBe('Within clinic range');
    expect(statusLabel('within_range', 'default')).toBe('Within default range');
    expect(statusLabel('outside_range', 'approved')).toBe('Outside range');
    expect(rangeLegendText(null, 5.7, '%')).toBe('Default range below 5.7%');
    expect(rangeLegendText(null, 5.5, '%', 'approved')).toBe('Clinic range below 5.5%');
  });
});
