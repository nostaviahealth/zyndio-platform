import React from 'react';

export interface DataTableColumn<T> {
  key: string;
  header: string;
  render: (row: T) => React.ReactNode;
  /** Pin this column to the right edge while the table scrolls sideways
   * inside its card (TC-019 M5: row actions stay visible at 1024px). */
  stickyRight?: boolean;
}

// Opaque backgrounds so cells scrolling underneath don't show through.
// TC-021 item 10 (Ava F2): a 1px inset left edge (border.subtle) marks the
// pinned column, so it reads as fixed while the rest of the row scrolls.
const PINNED_EDGE = 'shadow-[inset_1px_0_0_#E2E8F0] dark:shadow-[inset_1px_0_0_#222838]';
const STICKY_TH = `sticky right-0 bg-[#E6ECFA] dark:bg-[#0B0F19] ${PINNED_EDGE}`;
const STICKY_TD = `sticky right-0 bg-white dark:bg-[#10141F] ${PINNED_EDGE}`;

interface DataTableProps<T> {
  columns: DataTableColumn<T>[];
  rows: T[];
  getRowId: (row: T) => string;
  caption?: string;
}

// Generic C-series DataTable: a plain accessible <table>, one row per
// record, a render function per column so callers (actions, badges, links)
// stay in the page rather than leaking into this component.
// Header labels render as given (sentence case per Ava handoff) — do not
// force uppercase here.
function DataTable<T>({ columns, rows, getRowId, caption }: DataTableProps<T>) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full border-collapse text-left text-sm text-[#030616] dark:text-[#EEF1F8]">
        {caption && <caption className="sr-only">{caption}</caption>}
        <thead>
          <tr className="border-b border-slate-200 bg-[#E6ECFA] text-xs font-semibold text-[#48556A] dark:border-[#222838] dark:bg-[#0B0F19] dark:text-[#A6B0C3]">
            {columns.map((col) => (
              <th key={col.key} scope="col" className={`px-4 py-3${col.stickyRight ? ` ${STICKY_TH}` : ''}`}>
                {col.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={getRowId(row)} className="border-b border-slate-100 last:border-0 dark:border-[#222838]">
              {columns.map((col) => (
                <td key={col.key} className={`px-4 py-3 align-middle${col.stickyRight ? ` ${STICKY_TD}` : ''}`}>
                  {col.render(row)}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export default DataTable;
