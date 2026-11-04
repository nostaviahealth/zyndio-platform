import { PatientExport, ExportFormat } from './patientRecordApi';

// POR-06: turn the server's whitelisted export document into a file. JSON is
// the mapped document as-is; CSV is one flat table (one row per lab value,
// treatment and visit) so it opens in a spreadsheet without nesting.

export const CSV_COLUMNS = [
  'record_type',
  'date',
  'name',
  'key',
  'value',
  'original_value',
  'unit',
  'status',
  'range_low',
  'range_high',
  'range_source',
  'range_set_version',
  'source',
] as const;

type Cell = string | number | null | undefined;

/**
 * RFC 4180 quoting plus spreadsheet formula-injection defence: a text cell
 * starting with = + - @ (or tab / CR) is prefixed with a single quote so a
 * spreadsheet never evaluates it. Numbers pass through untouched, so a
 * negative value stays a number.
 */
export function csvCell(v: Cell): string {
  if (v === null || v === undefined) return '';
  if (typeof v === 'number') return Number.isFinite(v) ? String(v) : '';
  let s = String(v);
  if (/^[=+\-@\t\r]/.test(s)) s = `'${s}`;
  if (/[",\r\n]/.test(s)) s = `"${s.replace(/"/g, '""')}"`;
  return s;
}

export function toCsv(doc: PatientExport): string {
  const rows: Cell[][] = [];
  const p = doc.patient;
  rows.push(['patient', p.programStartedOn, p.displayName, p.mrn, null, null, null, null, null, null, null, null, p.sex]);
  for (const t of doc.treatments) {
    rows.push(['treatment', t.startedOn, t.name, null, null, null, null, t.status, null, null, null, null, t.source]);
  }
  for (const v of doc.visits) {
    rows.push(['visit', v.visitOn, 'Visit', null, null, null, null, null, null, null, null, null, null]);
  }
  for (const r of doc.labResults) {
    rows.push([
      'lab_result',
      r.takenAt,
      r.analyteLabel,
      r.analyteKey,
      r.value,
      r.originalValue,
      r.unit,
      r.status,
      r.rangeLow,
      r.rangeHigh,
      r.rangeSource,
      r.rangeSetVersion,
      null,
    ]);
  }
  const lines = [CSV_COLUMNS.join(','), ...rows.map((r) => r.map(csvCell).join(','))];
  return lines.join('\r\n') + '\r\n';
}

export function toJson(doc: PatientExport): string {
  return JSON.stringify(doc, null, 2) + '\n';
}

/** "zyndio-export-ZP-10482-2026-11-04.csv"; the MRN is sanitised for a file name. */
export function exportFileName(doc: PatientExport, format: ExportFormat, now: Date): string {
  const mrn = doc.patient.mrn.replace(/[^A-Za-z0-9_-]/g, '') || 'patient';
  const day = now.toISOString().slice(0, 10);
  return `zyndio-export-${mrn}-${day}.${format}`;
}

export function exportBlob(doc: PatientExport, format: ExportFormat): Blob {
  return format === 'csv'
    ? new Blob([toCsv(doc)], { type: 'text/csv;charset=utf-8' })
    : new Blob([toJson(doc)], { type: 'application/json' });
}

/** Browser download of the export (the live page; tests inject their own). */
export function downloadExport(doc: PatientExport, format: ExportFormat, now: Date = new Date()): void {
  const url = URL.createObjectURL(exportBlob(doc, format));
  const a = document.createElement('a');
  a.href = url;
  a.download = exportFileName(doc, format, now);
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 0);
}
