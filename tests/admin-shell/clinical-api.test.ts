import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock the supabase client the clinical API is built on. Each test sets the
// rpc return value; the point of these tests is the mapping layer, not the
// network - the live RPCs are covered by the pgTAP + integration suites.
const rpc = vi.fn();
vi.mock('../../lib/supabase', () => ({
  supabase: { rpc: (...args: unknown[]) => rpc(...args) },
}));

import {
  fetchRoster,
  fetchChipCounts,
  fetchLatestResults,
  fetchTrend,
  openPatientDetail,
} from '../../lib/clinicalApi';

beforeEach(() => rpc.mockReset());

describe('clinicalApi mapping (whitelist, no clinical leakage)', () => {
  it('openPatientDetail never surfaces a dose, even if the server sent one', async () => {
    rpc.mockResolvedValueOnce({
      data: {
        patient_id: 'p1',
        display_name: 'Jordan Rivera',
        mrn: 'ZP-10482',
        sex: 'female',
        birth_date: '1985-03-01',
        program_started_on: '2026-04-02',
        last_activity_at: '2026-10-20T13:12:00Z',
        treatment: {
          name: 'Example GLP-1 medication (fictional)',
          started_on: '2026-04-02',
          status: 'Active',
          source: 'Zyndio record, Oct 20, 2026',
          // The server should never send this, but if a future column leaked a
          // dose the mapper must drop it on the floor.
          dose: '2.4 mg weekly',
        },
      },
      error: null,
    });

    const detail = await openPatientDetail('p1');
    expect(detail).not.toBeNull();
    expect(detail!.treatment).not.toBeNull();
    const serialized = JSON.stringify(detail);
    expect(serialized).not.toMatch(/dose/i);
    expect(serialized).not.toContain('2.4 mg');
    // Only the whitelisted keys survive.
    expect(Object.keys(detail!.treatment!).sort()).toEqual(['name', 'source', 'startedOn', 'status']);
    expect(detail!.treatment!.name).toBe('Example GLP-1 medication (fictional)');
  });

  it('openPatientDetail maps a null payload to the not-found view state', async () => {
    rpc.mockResolvedValueOnce({ data: null, error: null });
    const detail = await openPatientDetail('nope');
    expect(detail).toBeNull();
  });

  it('openPatientDetail maps an RPC error to not-found rather than throwing', async () => {
    rpc.mockResolvedValueOnce({ data: null, error: { message: 'denied' } });
    await expect(openPatientDetail('p1')).resolves.toBeNull();
  });

  it('openPatientDetail keeps treatment null when the patient has none', async () => {
    rpc.mockResolvedValueOnce({
      data: { patient_id: 'p1', display_name: 'A', mrn: 'ZP-1', treatment: null },
      error: null,
    });
    const detail = await openPatientDetail('p1');
    expect(detail!.treatment).toBeNull();
  });

  it('fetchRoster maps rows + pre-limit total and only whitelisted flag keys', async () => {
    rpc.mockResolvedValueOnce({
      data: [
        {
          patient_id: 'p1',
          display_name: 'Jordan Rivera',
          mrn: 'ZP-10482',
          sex: 'female',
          birth_date: '1985-03-01',
          program_started_on: '2026-04-02',
          latest_lab_at: '2026-10-14T00:00:00Z',
          last_activity_at: '2026-10-20T13:12:00Z',
          open_questions: 1,
          flags: ['question_waiting'],
          total_count: 42,
        },
      ],
      error: null,
    });
    const result = await fetchRoster({ search: null, filter: 'all', sort: 'recent', limit: 8, offset: 0 });
    expect(result.totalCount).toBe(42);
    expect(result.rows).toHaveLength(1);
    expect(result.rows[0].flags).toEqual(['question_waiting']);
    expect(result.rows[0].displayName).toBe('Jordan Rivera');
    // No total_count leaks onto the row object.
    expect(JSON.stringify(result.rows[0])).not.toContain('total_count');
  });

  it('fetchRoster returns an empty page (total 0) with no rows', async () => {
    rpc.mockResolvedValueOnce({ data: [], error: null });
    const result = await fetchRoster({ search: 'Rivra', filter: 'all', sort: 'recent', limit: 8, offset: 0 });
    expect(result.rows).toEqual([]);
    expect(result.totalCount).toBe(0);
  });

  it('fetchRoster throws on an RPC error so the page can show its error state', async () => {
    rpc.mockResolvedValueOnce({ data: null, error: { message: 'boom' } });
    await expect(fetchRoster({ filter: 'all', sort: 'recent', limit: 8, offset: 0 })).rejects.toBeTruthy();
  });

  it('fetchChipCounts maps the single counts row', async () => {
    rpc.mockResolvedValueOnce({
      data: [{ all_count: 42, flagged_count: 6, missing_labs_count: 9, questions_waiting_count: 3 }],
      error: null,
    });
    const counts = await fetchChipCounts();
    expect(counts).toEqual({ all: 42, flagged: 6, missingLabs: 9, questionsWaiting: 3 });
  });

  it('fetchLatestResults maps analyte rows and preserves a null range', async () => {
    rpc.mockResolvedValueOnce({
      data: [
        {
          analyte_key: 'hba1c',
          analyte_label: 'HbA1c',
          value: 5.5,
          original_value: null,
          unit: '%',
          status: 'within_range',
          is_unmapped: false,
          range_low: null,
          range_high: 5.7,
          taken_at: '2026-10-14T00:00:00Z',
        },
        {
          analyte_key: 'insulin',
          analyte_label: 'Insulin, fasting',
          value: 9.4,
          original_value: null,
          unit: 'uIU/mL',
          status: 'no_range',
          is_unmapped: false,
          range_low: null,
          range_high: null,
          taken_at: '2026-10-14T00:00:00Z',
        },
      ],
      error: null,
    });
    const rows = await fetchLatestResults('p1');
    expect(rows).toHaveLength(2);
    expect(rows[0].analyteKey).toBe('hba1c');
    expect(rows[0].rangeHigh).toBe(5.7);
    expect(rows[1].rangeHigh).toBeNull();
    expect(rows[1].status).toBe('no_range');
  });

  it('fetchTrend keeps original_value so the history can show "was X"', async () => {
    rpc.mockResolvedValueOnce({
      data: [
        { taken_at: '2026-04-02T00:00:00Z', value: 6.2, original_value: null, unit: '%', status: 'baseline', range_low: null, range_high: 5.7 },
        { taken_at: '2026-10-14T00:00:00Z', value: 2.8, original_value: 2.4, unit: '%', status: 'within_range', range_low: null, range_high: 5.7 },
      ],
      error: null,
    });
    const points = await fetchTrend('p1', 'hba1c', '6M');
    expect(points).toHaveLength(2);
    expect(points[1].originalValue).toBe(2.4);
    expect(rpc).toHaveBeenCalledWith('patient_trend', { p_patient_id: 'p1', p_analyte: 'hba1c', p_period: '6M' });
  });

  it('fetchTrend maps the "All" period to the RPC\'s uppercase ALL token', async () => {
    rpc.mockResolvedValueOnce({ data: [], error: null });
    await fetchTrend('p1', 'hba1c', 'All');
    expect(rpc).toHaveBeenCalledWith('patient_trend', { p_patient_id: 'p1', p_analyte: 'hba1c', p_period: 'ALL' });
  });
});
