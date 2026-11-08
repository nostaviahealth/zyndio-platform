import React, { useCallback, useEffect, useState } from 'react';
import { Shield, RotateCw } from 'lucide-react';
import {
  AuditLogApi,
  AuditLogEntry,
  supabaseAuditLogApi,
} from '../../lib/auditLogApi';
import PageHeader from '../../components/ui/PageHeader';
import DataTable, { DataTableColumn } from '../../components/ui/DataTable';
import SelectField from '../../components/ui/SelectField';

export interface AuditLogProps {
  api?: AuditLogApi;
}

const ACTION_FILTER_OPTIONS = [
  { value: '', label: 'All actions' },
  { value: 'role_changed', label: 'Role changed' },
  { value: 'patient_detail_opened', label: 'Patient detail opened' },
  { value: 'treatment_event_recorded', label: 'Treatment event recorded' },
  { value: 'treatment_context_viewed', label: 'Treatment context viewed' },
  { value: 'partner_outcome_consent_granted', label: 'Partner outcome consent granted' },
  { value: 'partner_outcome_consent_revoked', label: 'Partner outcome consent revoked' },
  { value: 'password_lockout', label: 'Password lockout' },
  { value: 'mfa_lockout', label: 'MFA lockout' },
];

const AuditLog: React.FC<AuditLogProps> = ({ api = supabaseAuditLogApi }) => {
  const [entries, setEntries] = useState<AuditLogEntry[]>([]);
  const [actionFilter, setActionFilter] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  const loadEntries = useCallback(async (filter: string) => {
    setLoading(true);
    setError(null);
    try {
      const rows = await api.listOrgAuditLog({
        limit: 100,
        actionFilter: filter || null,
      });
      setEntries(rows);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unable to load organization audit log.');
    } finally {
      setLoading(false);
    }
  }, [api]);

  useEffect(() => {
    loadEntries(actionFilter);
  }, [actionFilter, loadEntries]);

  const columns: DataTableColumn<AuditLogEntry>[] = [
    {
      key: 'createdAt',
      header: 'Timestamp',
      render: (row) => (
        <span className="tabular-nums text-xs text-[#48556A] dark:text-[#A6B0C3]">
          {row.createdAt ? new Date(row.createdAt).toISOString().replace('T', ' ').slice(0, 19) : '—'}
        </span>
      ),
    },
    {
      key: 'action',
      header: 'Action',
      render: (row) => (
        <span className="inline-flex items-center rounded-md bg-[#E8EDFD] px-2 py-0.5 font-mono text-xs font-semibold text-[#2C5CF2] dark:bg-[#18224A] dark:text-[#AFC3FF]">
          {row.action}
        </span>
      ),
    },
    {
      key: 'actorId',
      header: 'Actor ID',
      render: (row) => (
        <span className="font-mono text-xs text-[#030616] dark:text-[#EEF1F8]">
          {row.actorId ?? 'system'}
        </span>
      ),
    },
    {
      key: 'targetId',
      header: 'Target ID',
      render: (row) => (
        <span className="font-mono text-xs text-[#030616] dark:text-[#EEF1F8]">
          {row.targetId ?? '—'}
        </span>
      ),
    },
    {
      key: 'metadata',
      header: 'Details',
      render: (row) => {
        const keys = Object.keys(row.metadata ?? {});
        if (keys.length === 0) {
          return <span className="text-xs text-slate-400 dark:text-[#6C7690]">—</span>;
        }
        return (
          <code className="text-xs text-[#48556A] dark:text-[#A6B0C3]">
            {JSON.stringify(row.metadata)}
          </code>
        );
      },
    },
  ];

  return (
    <div className="space-y-6">
      <PageHeader
        title="Audit log"
        description={`${entries.length} ${entries.length === 1 ? 'event' : 'events'}`}
        actions={
          <button
            type="button"
            onClick={() => loadEntries(actionFilter)}
            className="inline-flex min-h-[44px] items-center gap-2 rounded-full border border-slate-300 bg-white px-5 text-sm font-semibold text-[#030616] hover:bg-slate-50 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2] dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8] dark:hover:bg-[#222838]"
          >
            <RotateCw className="h-4 w-4" aria-hidden="true" />
            Refresh
          </button>
        }
      />

      <div className="flex flex-wrap items-center justify-between gap-4">
        <div className="w-full sm:w-72">
          <SelectField
            aria-label="Filter by action"
            wrapperClassName="w-full"
            value={actionFilter}
            onChange={(e) => setActionFilter(e.target.value)}
          >
            {ACTION_FILTER_OPTIONS.map((opt) => (
              <option key={opt.value} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </SelectField>
        </div>
        <div className="flex items-center gap-2 text-xs text-[#48556A] dark:text-[#A6B0C3]">
          <Shield className="h-4 w-4 text-[#2C5CF2] dark:text-[#7C9CFF]" aria-hidden="true" />
          <span>Append-only organization audit log (sanitized metadata)</span>
        </div>
      </div>

      {error ? (
        <div
          role="alert"
          className="rounded-2xl border border-[#B42318]/30 bg-[#FCE8E6] p-6 text-sm text-[#B42318] dark:border-[#FF8F86]/30 dark:bg-[#3A1614] dark:text-[#FF8F86]"
        >
          {error}
        </div>
      ) : loading ? (
        <p role="status" className="text-sm text-slate-500 dark:text-[#A6B0C3]">
          Loading audit log…
        </p>
      ) : entries.length === 0 ? (
        <div className="rounded-2xl border border-slate-200 bg-white p-12 text-center dark:border-[#222838] dark:bg-[#10141F]">
          <p className="text-base font-semibold text-[#030616] dark:text-[#EEF1F8]">
            No matching audit log events
          </p>
          <p className="mt-1 text-sm text-[#48556A] dark:text-[#A6B0C3]">
            Events for your organization will appear here as staff and patients interact with Zyndio.
          </p>
        </div>
      ) : (
        <DataTable
          columns={columns}
          rows={entries}
          getRowId={(r) => String(r.id)}
        />
      )}
    </div>
  );
};

export default AuditLog;
