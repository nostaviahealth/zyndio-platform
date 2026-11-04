import { PrevisitBrief, BriefMarker, BriefChange, MissingItem } from './patientRecordApi';
import { formatMonthDayYear, formatValue } from './clinicalFormat';

// POR-04: the pre-visit brief's ONLY wording. Every line is a fixed template
// filled from structured server facts (numbers, dates, marker labels); there
// is no free text and no AI-generated text anywhere in the brief. Changing a
// sentence here is a reviewed code change, pinned by tests/admin-shell/
// previsit-brief.test.ts.

export interface BriefSection {
  id: 'out_of_range' | 'changes' | 'flags' | 'missing';
  heading: string;
  lines: string[];
  /** Shown when `lines` is empty. */
  empty: string;
}

const plural = (n: number, one: string, many: string) => (n === 1 ? one : many);

/** "range 70–99 mg/dL" / "range up to 5.7 %" / "range from 40 mg/dL" */
export function rangePhrase(low: number | null, high: number | null, unit: string | null): string {
  const u = unit ? ` ${unit}` : '';
  if (low !== null && high !== null) return `range ${formatValue(low)}–${formatValue(high)}${u}`;
  if (high !== null) return `range up to ${formatValue(high)}${u}`;
  if (low !== null) return `range from ${formatValue(low)}${u}`;
  return 'no range set';
}

/** "Since the last visit on Oct 8, 2026" etc. */
export function sinceLine(b: PrevisitBrief): string {
  const d = formatMonthDayYear(b.since.date);
  switch (b.since.basis) {
    case 'last_visit':
      return `Since the last visit on ${d}`;
    case 'program_start':
      return `Since the program started on ${d} (no visit recorded yet)`;
    case 'first_result':
      return `Since the first lab result on ${d} (no visit recorded yet)`;
    default:
      return 'No visit, program start or lab result on record yet';
  }
}

export function summaryLine(b: PrevisitBrief): string {
  const n = b.counts.resultsSince;
  const m = b.counts.markersSince;
  if (b.since.basis === 'none') return 'No lab results on record.';
  if (n === 0) return 'No new lab results in this period.';
  return `${n} lab ${plural(n, 'result', 'results')} across ${m} ${plural(m, 'marker', 'markers')} in this period.`;
}

export function treatmentLine(b: PrevisitBrief): string | null {
  if (!b.treatment) return null;
  const parts = [`Treatment: ${b.treatment.name}`];
  if (b.treatment.status) parts.push(b.treatment.status);
  if (b.treatment.startedOn) parts.push(`started ${formatMonthDayYear(b.treatment.startedOn)}`);
  return parts.join(' · ');
}

export function outOfRangeLine(m: BriefMarker): string {
  const source = m.rangeSource === 'approved' ? 'clinic' : 'default';
  const unit = m.unit ? ` ${m.unit}` : '';
  return `${m.analyteLabel}: ${formatValue(m.value)}${unit} on ${formatMonthDayYear(m.takenAt)}, outside the ${source} ${rangePhrase(
    m.rangeLow,
    m.rangeHigh,
    m.unit
  )}.`;
}

export function changeLine(c: BriefChange): string {
  const unit = c.unit ? ` ${c.unit}` : '';
  const delta = c.delta ?? 0;
  // Round only the difference, to the larger of the two values' decimals, so
  // float noise (0.79999…) never reaches the page. Values print as stored.
  const decimals = Math.max(decimalsOf(c.baselineValue), decimalsOf(c.latestValue));
  const magnitude = Math.abs(delta).toFixed(decimals);
  const change = delta === 0 ? 'no change' : `${delta < 0 ? '−' : '+'}${magnitude}`;
  return `${c.analyteLabel}: ${formatValue(c.baselineValue)} → ${formatValue(c.latestValue)}${unit} (${change}), ${formatMonthDayYear(
    c.baselineAt
  )} to ${formatMonthDayYear(c.latestAt)}.`;
}

function decimalsOf(v: number | null): number {
  if (v === null) return 0;
  const s = String(v);
  const i = s.indexOf('.');
  return i < 0 ? 0 : s.length - i - 1;
}

export function flagLines(b: PrevisitBrief): string[] {
  const lines: string[] = [];
  const nr = b.flags.needsReview;
  if (nr > 0) lines.push(`${nr} ${plural(nr, 'marker needs', 'markers need')} checking against the report.`);
  if (b.flags.identityHold) lines.push('A lab report is on identity hold until the patient confirms it is theirs.');
  const q = b.flags.openQuestions;
  if (q > 0) lines.push(`${q} open ${plural(q, 'question', 'questions')} from the patient.`);
  return lines;
}

export function missingLine(m: MissingItem): string {
  switch (m.code) {
    case 'no_labs':
      return 'No lab results on record.';
    case 'no_labs_since_visit':
      return 'No lab results since the last visit.';
    case 'labs_stale':
      return `Latest lab result is ${m.days ?? '?'} days old (${formatMonthDayYear(m.latestAt)}).`;
    case 'marker_not_rechecked':
      return `${m.analyteLabel} not rechecked since the last visit (last result ${formatMonthDayYear(m.lastAt)}).`;
    case 'no_treatment':
      return 'No treatment on record.';
  }
}

export function briefSections(b: PrevisitBrief): BriefSection[] {
  return [
    {
      id: 'out_of_range',
      heading: 'Latest results outside range',
      lines: b.outOfRange.map(outOfRangeLine),
      empty: 'No latest result is outside its range.',
    },
    {
      id: 'changes',
      heading: 'Changes since baseline',
      lines: b.changes.map(changeLine),
      empty: 'No marker has a baseline and a later result yet.',
    },
    {
      id: 'flags',
      heading: 'Open flags',
      lines: flagLines(b),
      empty: 'No open flags.',
    },
    {
      id: 'missing',
      heading: 'Missing data',
      lines: b.missing.map(missingLine),
      empty: 'Nothing missing.',
    },
  ];
}
