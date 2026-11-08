import React, { useCallback, useEffect, useState } from 'react';
import { Info, Plus, ShieldCheck, Trash2 } from 'lucide-react';
import PageHeader from '../../../components/ui/PageHeader';
import Dialog from '../../../components/ui/Dialog';
import Button from '../../../components/admin-auth/Button';
import TextInput from '../../../components/ui/TextInput';
import SelectField from '../../../components/ui/SelectField';
import CriticalBanner from '../../../components/ui/CriticalBanner';
import FictionalDataTag from '../../../components/ui/FictionalDataTag';
import {
  RangeItem,
  RangeItemInput,
  RangeSet,
  RangeSex,
  RangesApi,
  supabaseRangesApi,
} from '../../../lib/clinicConfigApi';
import { formatMonthDayYear, formatValue } from '../../../lib/clinicalFormat';

// POR-05: the clinic's versioned reference ranges. A physician drafts a new
// version (pre-filled from the live one), edits rows, and approves it; only
// then do lab flags use it. Care coordinators and read-only staff can see the
// sets but not change them. The server enforces all of this and audits each
// change; this page only reflects it.

const SEX_LABELS: Record<RangeSex, string> = { any: 'Any', female: 'Female', male: 'Male' };
const STATUS_LABELS: Record<RangeSet['status'], string> = {
  draft: 'Draft',
  approved: 'Live',
  superseded: 'Superseded',
  discarded: 'Discarded',
};

const CARD = 'rounded-2xl border border-slate-200 bg-white p-6 dark:border-[#222838] dark:bg-[#10141F]';

export interface ReferenceRangesProps {
  api?: RangesApi;
  viewerRole?: string | null;
}

export function validateRangeItem(i: RangeItemInput): string | null {
  if (!/^[a-z0-9_]{1,64}$/.test(i.analyteKey)) return 'Marker key: lowercase letters, digits and _ only.';
  if (!i.analyteLabel.trim()) return 'Enter the marker name.';
  if (!i.unit.trim()) return 'Enter the unit, exactly as results report it.';
  if (i.low === null && i.high === null) return 'Enter a low, a high, or both.';
  if (i.low !== null && i.high !== null && i.low >= i.high) return 'Low must be less than high.';
  return null;
}

function parseBound(s: string): number | null | 'invalid' {
  const t = s.trim();
  if (t === '') return null;
  const n = Number(t);
  return Number.isFinite(n) ? n : 'invalid';
}

const ReferenceRanges: React.FC<ReferenceRangesProps> = ({ api = supabaseRangesApi, viewerRole }) => {
  const canEdit = viewerRole === 'physician';
  const [sets, setSets] = useState<RangeSet[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [items, setItems] = useState<RangeItem[] | null>(null);
  const [confirm, setConfirm] = useState<'approve' | 'discard' | null>(null);
  const [busy, setBusy] = useState(false);

  const live = sets?.find((s) => s.status === 'approved') ?? null;
  const draft = sets?.find((s) => s.status === 'draft') ?? null;
  const selected = sets?.find((s) => s.id === selectedId) ?? null;

  const loadSets = useCallback(async () => {
    setError(null);
    try {
      const list = await api.listRangeSets();
      setSets(list);
      setSelectedId((cur) =>
        cur && list.some((s) => s.id === cur)
          ? cur
          : (list.find((s) => s.status === 'draft') ?? list.find((s) => s.status === 'approved') ?? list[0])?.id ?? null
      );
    } catch {
      setSets([]);
      setError("We couldn't load your clinic's range sets. Check your connection and try again.");
    }
  }, [api]);

  useEffect(() => {
    loadSets();
  }, [loadSets]);

  const loadItems = useCallback(async () => {
    if (!selectedId) {
      setItems(null);
      return;
    }
    setItems(null);
    try {
      setItems(await api.fetchRangeItems(selectedId));
    } catch {
      setItems([]);
      setError("We couldn't load this range set's rows. Try again.");
    }
  }, [api, selectedId]);

  useEffect(() => {
    loadItems();
  }, [loadItems]);

  const act = async (fn: () => Promise<unknown>, failure: string) => {
    setBusy(true);
    setError(null);
    try {
      await fn();
      await loadSets();
      await loadItems();
      return true;
    } catch {
      setError(failure);
      return false;
    } finally {
      setBusy(false);
    }
  };

  const startDraft = async () => {
    setBusy(true);
    setError(null);
    try {
      const id = await api.createDraft(null);
      setSelectedId(id);
      await loadSets();
    } catch {
      setError("We couldn't start a draft. Another draft may already exist. Refresh and try again.");
    } finally {
      setBusy(false);
    }
  };

  const isDraftSelected = selected?.status === 'draft';

  return (
    <div className="relative">
      {typeof __PREVIEW_BUILD__ !== 'undefined' && __PREVIEW_BUILD__ && <FictionalDataTag />}
      <PageHeader
        title="Reference ranges"
        description="The ranges your clinic uses to flag lab results. A physician drafts changes and approves them before they go live. Every change is recorded in the audit log."
        actions={
          canEdit && sets !== null && !draft ? (
            <Button type="button" onClick={startDraft} busy={busy} busyLabel="Starting…">
              <Plus className="h-4 w-4" aria-hidden="true" />
              {live ? 'Start a new version' : 'Start the first range set'}
            </Button>
          ) : undefined
        }
      />

      {error && (
        <div className="mt-6">
          <CriticalBanner>{error}</CriticalBanner>
        </div>
      )}

      <div className={`mt-6 ${CARD}`}>
        {sets === null ? (
          <p className="text-sm text-[#48556A] dark:text-[#A6B0C3]" role="status">
            Loading…
          </p>
        ) : live ? (
          <div className="flex gap-3">
            <ShieldCheck className="mt-0.5 h-5 w-5 shrink-0 text-[#2C5CF2] dark:text-[#7C9CFF]" aria-hidden="true" />
            <p className="text-sm text-[#030616] dark:text-[#EEF1F8]">
              <span className="font-semibold">Version {live.version} is live.</span> Approved
              {live.approvedByName ? ` by ${live.approvedByName}` : ''} on {formatMonthDayYear(live.approvedAt)} ·{' '}
              {live.itemCount} {live.itemCount === 1 ? 'range' : 'ranges'}. Markers without a row here keep the general
              default range and its caveat.
            </p>
          </div>
        ) : (
          <div className="flex gap-3">
            <Info className="mt-0.5 h-5 w-5 shrink-0 text-slate-400 dark:text-[#8F9AAF]" aria-hidden="true" />
            <p className="text-sm text-[#48556A] dark:text-[#A6B0C3]">
              No approved range set yet. Lab results use the general default range and show the default-range caveat
              until a physician approves your clinic&apos;s ranges.
            </p>
          </div>
        )}
      </div>

      {sets && sets.length > 0 && (
        <div className="mt-6 grid gap-6 xl:grid-cols-[1fr_300px]">
          <div className={CARD}>
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <h2 className="text-xl font-bold text-[#030616] dark:text-[#EEF1F8]">
                  {selected ? `Version ${selected.version}` : 'Range set'}
                  {selected && <SetStatusBadge status={selected.status} />}
                </h2>
                {selected?.note && <p className="mt-1 text-sm text-[#48556A] dark:text-[#A6B0C3]">{selected.note}</p>}
              </div>
              {isDraftSelected && canEdit && (
                <div className="flex gap-3">
                  <Button type="button" variant="outline" onClick={() => setConfirm('discard')} disabled={busy}>
                    Discard draft
                  </Button>
                  <Button type="button" onClick={() => setConfirm('approve')} disabled={busy || !items || items.length === 0}>
                    Approve and make live
                  </Button>
                </div>
              )}
            </div>

            <RangeTable
              items={items}
              editable={isDraftSelected && canEdit}
              onDelete={(id) => act(() => api.deleteItem(id), "We couldn't delete that row. Try again.")}
            />

            {isDraftSelected && canEdit && selected && (
              <AddRangeRow
                busy={busy}
                onSave={(input) => act(() => api.saveItem(selected.id, input), "We couldn't save that row. Check the values and try again.")}
              />
            )}
            {isDraftSelected && !canEdit && (
              <p className="mt-4 text-sm text-[#48556A] dark:text-[#A6B0C3]">Only a physician can edit or approve a draft.</p>
            )}
          </div>

          <div className={CARD}>
            <h2 className="text-[13px] font-semibold uppercase tracking-wide text-slate-500 dark:text-[#A6B0C3]">Versions</h2>
            <ul className="mt-3 space-y-1">
              {sets.map((s) => (
                <li key={s.id}>
                  <button
                    type="button"
                    aria-current={s.id === selectedId ? 'true' : undefined}
                    onClick={() => setSelectedId(s.id)}
                    className={`flex min-h-[44px] w-full items-center justify-between gap-3 rounded-lg px-3 text-left text-sm focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2] ${
                      s.id === selectedId ? 'bg-[#EFF4FF] dark:bg-[#18224A]' : 'hover:bg-[#F5F7FD] dark:hover:bg-[#151A27]'
                    }`}
                  >
                    <span className="whitespace-nowrap font-semibold text-[#030616] dark:text-[#EEF1F8]">Version {s.version}</span>
                    <span className="text-[13px] text-[#48556A] dark:text-[#A6B0C3]">
                      {STATUS_LABELS[s.status]}
                      {s.approvedAt ? ` · ${formatMonthDayYear(s.approvedAt)}` : ''}
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          </div>
        </div>
      )}

      {confirm === 'approve' && selected && (
        <Dialog
          titleId="approve-ranges-title"
          descriptionId="approve-ranges-body"
          title={`Approve version ${selected.version}?`}
          onClose={() => setConfirm(null)}
        >
          <p id="approve-ranges-body" className="mt-2 text-sm text-slate-600 dark:text-[#A6B0C3]">
            Lab flags for every patient in your clinic switch to these {items?.length ?? 0} ranges now
            {live ? `, replacing version ${live.version}` : ''}. The approval is recorded in the audit log under your
            name, and the approved version can&apos;t be edited afterwards.
          </p>
          <div className="mt-6 flex justify-end gap-3">
            <Button type="button" variant="outline" onClick={() => setConfirm(null)} data-autofocus="true">
              Cancel
            </Button>
            <Button
              type="button"
              busy={busy}
              busyLabel="Approving…"
              onClick={async () => {
                await act(() => api.approve(selected.id), "We couldn't approve this version. Nothing changed. Try again.");
                setConfirm(null);
              }}
            >
              Approve and make live
            </Button>
          </div>
        </Dialog>
      )}

      {confirm === 'discard' && selected && (
        <Dialog
          titleId="discard-ranges-title"
          descriptionId="discard-ranges-body"
          title={`Discard draft version ${selected.version}?`}
          onClose={() => setConfirm(null)}
        >
          <p id="discard-ranges-body" className="mt-2 text-sm text-slate-600 dark:text-[#A6B0C3]">
            The draft stays in the version history as discarded. The live ranges don&apos;t change.
          </p>
          <div className="mt-6 flex justify-end gap-3">
            <Button type="button" variant="outline" onClick={() => setConfirm(null)} data-autofocus="true">
              Cancel
            </Button>
            <Button
              type="button"
              variant="destructive"
              busy={busy}
              onClick={async () => {
                await act(() => api.discard(selected.id), "We couldn't discard this draft. Try again.");
                setConfirm(null);
              }}
            >
              Discard draft
            </Button>
          </div>
        </Dialog>
      )}
    </div>
  );
};

const SetStatusBadge: React.FC<{ status: RangeSet['status'] }> = ({ status }) => (
  <span
    className={`ml-3 inline-flex items-center rounded-md px-2 py-0.5 align-middle text-xs font-semibold ${
      status === 'approved'
        ? 'bg-[#E8EDFD] text-[#2C5CF2] dark:bg-[#18224A] dark:text-[#AFC3FF]'
        : status === 'draft'
          ? 'bg-[#FCEFD6] text-[#8A4F00] dark:bg-[#2F220D] dark:text-[#F2B65A]'
          : 'bg-[#EEF1F6] text-[#48556A] dark:bg-[#0B0F19] dark:text-[#A6B0C3]'
    }`}
  >
    {STATUS_LABELS[status]}
  </span>
);

const RangeTable: React.FC<{ items: RangeItem[] | null; editable: boolean; onDelete: (id: string) => void }> = ({
  items,
  editable,
  onDelete,
}) => {
  if (items === null) {
    return (
      <p className="mt-4 text-sm text-[#48556A] dark:text-[#A6B0C3]" role="status">
        Loading ranges…
      </p>
    );
  }
  if (items.length === 0) {
    return <p className="mt-4 text-sm text-[#48556A] dark:text-[#A6B0C3]">No ranges in this version yet.</p>;
  }
  return (
    <table className="mt-4 w-full text-sm">
      <thead>
        <tr className="border-b border-slate-200 text-left text-[13px] text-slate-500 dark:border-[#222838] dark:text-[#8F9AAF]">
          <th className="py-2 pr-4 font-semibold">Marker</th>
          <th className="py-2 pr-4 font-semibold">Sex</th>
          <th className="py-2 pr-4 font-semibold">Low</th>
          <th className="py-2 pr-4 font-semibold">High</th>
          <th className="py-2 pr-4 font-semibold">Unit</th>
          {editable && (
            <th className="py-2 font-semibold">
              <span className="sr-only">Actions</span>
            </th>
          )}
        </tr>
      </thead>
      <tbody className="divide-y divide-slate-100 dark:divide-[#222838]">
        {items.map((i) => (
          <tr key={i.id}>
            <td className="py-2 pr-4">
              <span className="font-semibold text-[#030616] dark:text-[#EEF1F8]">{i.analyteLabel}</span>
              <span className="ml-2 text-[13px] text-slate-500 dark:text-[#8F9AAF]">{i.analyteKey}</span>
            </td>
            <td className="py-2 pr-4 text-[#030616] dark:text-[#EEF1F8]">{SEX_LABELS[i.sex]}</td>
            <td className="py-2 pr-4 tabular-nums text-[#030616] dark:text-[#EEF1F8]">{i.low === null ? '—' : formatValue(i.low)}</td>
            <td className="py-2 pr-4 tabular-nums text-[#030616] dark:text-[#EEF1F8]">{i.high === null ? '—' : formatValue(i.high)}</td>
            <td className="py-2 pr-4 text-[#030616] dark:text-[#EEF1F8]">{i.unit}</td>
            {editable && (
              <td className="py-2 text-right">
                <button
                  type="button"
                  onClick={() => onDelete(i.id)}
                  aria-label={`Delete ${i.analyteLabel} (${SEX_LABELS[i.sex]})`}
                  className="inline-flex h-11 w-11 items-center justify-center rounded-full text-slate-500 hover:bg-slate-100 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2] dark:text-[#A6B0C3] dark:hover:bg-[#222838]"
                >
                  <Trash2 className="h-4 w-4" aria-hidden="true" />
                </button>
              </td>
            )}
          </tr>
        ))}
      </tbody>
    </table>
  );
};

// Saving a row with an existing marker + sex replaces that row (server upsert).
const AddRangeRow: React.FC<{ busy: boolean; onSave: (i: RangeItemInput) => Promise<boolean> }> = ({ busy, onSave }) => {
  const [key, setKey] = useState('');
  const [label, setLabel] = useState('');
  const [sex, setSex] = useState<RangeSex>('any');
  const [low, setLow] = useState('');
  const [high, setHigh] = useState('');
  const [unit, setUnit] = useState('');
  const [problem, setProblem] = useState<string | null>(null);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    const lo = parseBound(low);
    const hi = parseBound(high);
    if (lo === 'invalid' || hi === 'invalid') {
      setProblem('Low and high must be numbers.');
      return;
    }
    const input: RangeItemInput = { analyteKey: key.trim().toLowerCase(), analyteLabel: label.trim(), sex, low: lo, high: hi, unit: unit.trim() };
    const v = validateRangeItem(input);
    setProblem(v);
    if (v) return;
    if (await onSave(input)) {
      setKey('');
      setLabel('');
      setSex('any');
      setLow('');
      setHigh('');
      setUnit('');
    }
  };

  const field = 'text-[13px] font-semibold text-[#48556A] dark:text-[#A6B0C3]';
  return (
    <form onSubmit={submit} aria-label="Add or replace a range" className="mt-6 border-t border-slate-200 pt-5 dark:border-[#222838]">
      <h3 className="text-[15px] font-semibold text-[#030616] dark:text-[#EEF1F8]">Add or replace a range</h3>
      <div className="mt-3 grid grid-cols-2 gap-3 lg:grid-cols-6">
        <label className={field}>
          Marker key
          <TextInput value={key} onChange={(e) => setKey(e.target.value)} placeholder="hba1c" className="mt-1" />
        </label>
        <label className={field}>
          Marker name
          <TextInput value={label} onChange={(e) => setLabel(e.target.value)} placeholder="HbA1c" className="mt-1" />
        </label>
        <label className={field}>
          Sex
          <SelectField value={sex} onChange={(e) => setSex(e.target.value as RangeSex)} wrapperClassName="mt-1 w-full">
            <option value="any">Any</option>
            <option value="female">Female</option>
            <option value="male">Male</option>
          </SelectField>
        </label>
        <label className={field}>
          Low
          <TextInput value={low} onChange={(e) => setLow(e.target.value)} inputMode="decimal" className="mt-1" />
        </label>
        <label className={field}>
          High
          <TextInput value={high} onChange={(e) => setHigh(e.target.value)} inputMode="decimal" className="mt-1" />
        </label>
        <label className={field}>
          Unit
          <TextInput value={unit} onChange={(e) => setUnit(e.target.value)} placeholder="%" className="mt-1" />
        </label>
      </div>
      {problem && (
        <p role="alert" className="mt-2 text-[13px] text-[#B42318] dark:text-[#FF8F86]">
          {problem}
        </p>
      )}
      <p className="mt-2 text-[13px] text-slate-500 dark:text-[#8F9AAF]">
        A range applies only to results reported in the same unit. A sex-specific row wins over &quot;Any&quot;.
      </p>
      <Button type="submit" variant="outline" className="mt-3" busy={busy}>
        Save range
      </Button>
    </form>
  );
};

export default ReferenceRanges;
