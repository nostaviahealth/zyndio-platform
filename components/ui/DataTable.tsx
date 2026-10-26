import React from 'react';

export interface DataTableColumn<T> {
  key: string;
  header: string;
  render: (row: T) => React.ReactNode;
}

interface DataTableProps<T> {
  columns: DataTableColumn<T>[];
  rows: T[];
  getRowId: (row: T) => string;
  caption?: string;
}

// Generic C-series DataTable: a plain accessible <table>, one row per
// record, a render function per column so callers (actions, badges, links)
// stay in the page rather than leaking into this component.
function DataTable<T>({ columns, rows, getRowId, caption }: DataTableProps<T>) {
  return (
    <table className="w-full border-collapse text-left text-sm">
      {caption && <caption className="sr-only">{caption}</caption>}
      <thead>
        <tr className="border-b border-slate-200 text-xs font-semibold uppercase tracking-wide text-slate-500">
          {columns.map((col) => (
            <th key={col.key} scope="col" className="px-4 py-3">
              {col.header}
            </th>
          ))}
        </tr>
      </thead>
      <tbody>
        {rows.map((row) => (
          <tr key={getRowId(row)} className="border-b border-slate-100 last:border-0">
            {columns.map((col) => (
              <td key={col.key} className="px-4 py-3 align-middle">
                {col.render(row)}
              </td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  );
}

export default DataTable;
