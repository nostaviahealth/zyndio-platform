import { TimelineEvent } from './patientRecordApi';

// POR-03: display wording for timeline events. New sources (wearable_daily,
// food_logs, companion escalations) add an entry to SOURCE_META when their
// server-side source lands; an unknown source still renders with its title
// and a generic label, so the server can ship a source before the UI does.

export const SOURCE_META: Record<string, { label: string }> = {
  labs: { label: 'Labs' },
  treatment: { label: 'Treatment' },
  program: { label: 'Program' },
  visits: { label: 'Visit' },
};

export function sourceLabel(source: string): string {
  return SOURCE_META[source]?.label ?? 'Other';
}

/** "metabolic_panel" -> "Metabolic panel" */
export function humanize(key: string | null | undefined): string {
  if (!key) return '';
  const s = key.replace(/[_-]+/g, ' ').trim();
  return s.charAt(0).toUpperCase() + s.slice(1);
}

export function eventTitle(e: TimelineEvent): string {
  switch (e.eventType) {
    case 'lab_report':
    case 'lab_report_received':
      return humanize(e.detail.reportType ?? e.title) || 'Lab report';
    case 'treatment_started':
      return `${e.title} started`;
    case 'program_started':
      return 'Program started';
    case 'visit':
      return 'Visit';
    default:
      return e.title;
  }
}

export function eventSummary(e: TimelineEvent): string | null {
  switch (e.eventType) {
    case 'lab_report': {
      const n = e.detail.resultCount ?? 0;
      const parts = [`${n} ${n === 1 ? 'result' : 'results'}`];
      const out = e.detail.outsideCount ?? 0;
      const nr = e.detail.needsReviewCount ?? 0;
      if (out > 0) parts.push(`${out} outside range`);
      if (nr > 0) parts.push(`${nr} ${nr === 1 ? 'needs' : 'need'} review`);
      return parts.join(' · ');
    }
    case 'lab_report_received':
      return 'Report received. Values appear here after they are read and checked.';
    case 'treatment_started':
      return [e.detail.treatmentStatus, e.detail.treatmentSource].filter(Boolean).join(' · ') || null;
    default:
      return null;
  }
}
