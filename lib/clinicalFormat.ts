import { LabStatus } from './clinicalApi';

// Shared, clinician-approved display formatting for the physician portal.
// Everything is computed in UTC so screenshots are deterministic regardless
// of the machine timezone, and so a fixed fixture "now" reproduces the
// copy-deck strings exactly. The live pages pass `new Date()`; the preview
// harness passes a fixed fixture date.

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

function parse(iso: string | null): Date | null {
  if (!iso) return null;
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? null : d;
}

/** "Oct 14, 2026" */
export function formatMonthDayYear(iso: string | null): string {
  const d = parse(iso);
  if (!d) return '';
  return `${MONTHS[d.getUTCMonth()]} ${d.getUTCDate()}, ${d.getUTCFullYear()}`;
}

/** "Oct 14" (marker list / chart axis labels). */
export function formatMonthDay(iso: string | null): string {
  const d = parse(iso);
  if (!d) return '';
  return `${MONTHS[d.getUTCMonth()]} ${d.getUTCDate()}`;
}

function sameUtcDay(a: Date, b: Date): boolean {
  return (
    a.getUTCFullYear() === b.getUTCFullYear() &&
    a.getUTCMonth() === b.getUTCMonth() &&
    a.getUTCDate() === b.getUTCDate()
  );
}

/** "Today, 9:12 AM" when the activity is today, else "Oct 20, 2026". */
export function formatLastActivity(iso: string | null, now: Date): string {
  const d = parse(iso);
  if (!d) return '';
  if (sameUtcDay(d, now)) {
    let h = d.getUTCHours();
    const m = d.getUTCMinutes();
    const ampm = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    if (h === 0) h = 12;
    return `Today, ${h}:${String(m).padStart(2, '0')} ${ampm}`;
  }
  return formatMonthDayYear(iso);
}

const MS_PER_DAY = 24 * 60 * 60 * 1000;

/** Whole years since the birth date, as of `now`. */
export function ageFromBirthDate(birthDate: string | null, now: Date): number | null {
  const d = parse(birthDate);
  if (!d) return null;
  let age = now.getUTCFullYear() - d.getUTCFullYear();
  const beforeBirthday =
    now.getUTCMonth() < d.getUTCMonth() ||
    (now.getUTCMonth() === d.getUTCMonth() && now.getUTCDate() < d.getUTCDate());
  if (beforeBirthday) age -= 1;
  return age;
}

/** Program week (1-based weeks elapsed since the program start). */
export function programWeek(startedOn: string | null, now: Date): number | null {
  const d = parse(startedOn);
  if (!d) return null;
  const days = Math.floor((now.getTime() - d.getTime()) / MS_PER_DAY);
  if (days < 0) return null;
  return Math.floor(days / 7);
}

/** "41 · F" for the roster Age · Sex column. */
export function ageSexShort(birthDate: string | null, sex: string | null, now: Date): string {
  const age = ageFromBirthDate(birthDate, now);
  const short = sex ? sex.trim().charAt(0).toUpperCase() : '';
  if (age === null) return short;
  return short ? `${age} · ${short}` : String(age);
}

/** "Female" for the detail meta line. */
export function sexFull(sex: string | null): string {
  if (!sex) return '';
  const s = sex.trim();
  return s.charAt(0).toUpperCase() + s.slice(1).toLowerCase();
}

/** Numbers render as printed - no reformatting of the lab value itself. */
export function formatValue(value: number | null): string {
  if (value === null) return '';
  return String(value);
}

export const STATUS_LABELS: Record<LabStatus, string> = {
  within_range: 'Within default range',
  outside_range: 'Outside range',
  needs_review: 'Needs review',
  baseline: 'Baseline',
  no_range: 'No range set yet',
};

/**
 * C59/C30 trend chart y-axis: grid at 0.5 steps over the domain rounded out
 * to the nearest 0.5 (e.g. values 5.5-6.2 -> ticks 5 / 5.5 / 6 / 6.5). Takes
 * every plotted value plus any range band bounds, so the band is always
 * inside the drawn grid.
 */
export function yAxisTicks(values: number[]): number[] {
  if (values.length === 0) return [0, 1];
  const min = Math.floor((Math.min(...values) - 0.3) * 2) / 2;
  const max = Math.ceil((Math.max(...values) + 0.3) * 2) / 2;
  const ticks: number[] = [];
  for (let v = min; v <= max + 1e-9; v += 0.5) {
    ticks.push(Math.round(v * 2) / 2);
  }
  return ticks;
}

/** "Default range below 5.7%" / "4.0–5.6%" / "above 2.6%", or null for no band. */
export function rangeLegendText(
  rangeLow: number | null,
  rangeHigh: number | null,
  unit: string | null
): string | null {
  const u = unit ?? '';
  if (rangeLow === null && rangeHigh === null) return null;
  if (rangeLow === null && rangeHigh !== null) return `Default range below ${rangeHigh}${u}`;
  if (rangeLow !== null && rangeHigh === null) return `Default range above ${rangeLow}${u}`;
  return `Default range ${rangeLow}–${rangeHigh}${u}`;
}
