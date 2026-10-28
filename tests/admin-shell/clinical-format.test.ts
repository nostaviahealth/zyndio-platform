import { describe, it, expect } from 'vitest';
import {
  formatMonthDayYear,
  formatMonthDay,
  formatLastActivity,
  ageFromBirthDate,
  programWeek,
  ageSexShort,
  sexFull,
  rangeLegendText,
  STATUS_LABELS,
} from '../../lib/clinicalFormat';
import { FLAG_LABELS } from '../../components/clinical/FlagBadge';

const NOW = new Date('2026-10-18T10:00:00Z');

describe('clinicalFormat (UTC, deterministic)', () => {
  it('formats dates as the copy deck prints them', () => {
    expect(formatMonthDayYear('2026-10-14T12:00:00Z')).toBe('Oct 14, 2026');
    expect(formatMonthDay('2026-10-14T12:00:00Z')).toBe('Oct 14');
    expect(formatMonthDayYear(null)).toBe('');
  });

  it('shows "Today, h:mm AM" only on the same UTC day', () => {
    expect(formatLastActivity('2026-10-18T09:12:00Z', NOW)).toBe('Today, 9:12 AM');
    expect(formatLastActivity('2026-10-20T00:00:00Z', NOW)).toBe('Oct 20, 2026');
  });

  it('computes age and program week to match the copy deck', () => {
    expect(ageFromBirthDate('1985-03-01', NOW)).toBe(41);
    // Apr 2 2026 -> Oct 18 2026 = 199 days -> week 28.
    expect(programWeek('2026-04-02T00:00:00Z', NOW)).toBe(28);
    expect(ageSexShort('1985-03-01', 'female', NOW)).toBe('41 · F');
    expect(sexFull('female')).toBe('Female');
  });

  it('builds the range legend / status labels', () => {
    expect(rangeLegendText(null, 5.7, '%')).toBe('Default range below 5.7%');
    expect(rangeLegendText(null, null, '%')).toBeNull();
    expect(STATUS_LABELS.within_range).toBe('Within default range');
    expect(STATUS_LABELS.no_range).toBe('No range set yet');
  });

  it('labels every flag key (POR-02 set, no severity wording)', () => {
    expect(FLAG_LABELS.question_waiting).toBe('Question waiting');
    expect(FLAG_LABELS.identity_hold).toBe('Identity hold');
    expect(FLAG_LABELS.clinical_context).toBe('Clinical context');
  });
});
