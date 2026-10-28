import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { ChevronLeft, ChevronRight, Search, ArrowDownUp } from 'lucide-react';
import {
  ClinicalApi,
  ChipCounts,
  RosterFilter,
  RosterPatient,
  RosterSort,
  supabaseClinicalApi,
} from '../../../lib/clinicalApi';
import { usePortalAuth } from '../../../contexts/PortalAuthContext';
import FictionalDataTag from '../../../components/ui/FictionalDataTag';
import FlagBadge from '../../../components/clinical/FlagBadge';
import {
  ageSexShort,
  formatLastActivity,
  formatMonthDayYear,
  programWeek,
} from '../../../lib/clinicalFormat';

const PAGE_SIZE = 8;

const SORT_OPTIONS: { value: RosterSort; label: string }[] = [
  { value: 'recent', label: 'Sort: Recent activity' },
  { value: 'questions_waiting', label: 'Sort: Oldest question first' },
  { value: 'name', label: 'Sort: Name' },
];

interface Chip {
  key: RosterFilter;
  label: string;
  count: (c: ChipCounts) => number;
}

const CHIPS: Chip[] = [
  { key: 'all', label: 'All', count: (c) => c.all },
  { key: 'flagged', label: 'Flagged', count: (c) => c.flagged },
  { key: 'missing_labs', label: 'Missing labs', count: (c) => c.missingLabs },
  { key: 'questions_waiting', label: 'Questions waiting', count: (c) => c.questionsWaiting },
];

export interface PhysicianRosterProps {
  api?: ClinicalApi;
  now?: Date;
  // Live route derives the role from PortalAuth; the preview harness passes it
  // explicitly. read_only rows are NOT links (Henry 26 Oct).
  role?: string | null;
  initialSearch?: string;
  initialFilter?: RosterFilter;
  initialSort?: RosterSort;
}

// 01-patient-list, built on the step-A read model (clinicalApi). The same
// component backs the live /admin/roster route and the /__preview harness;
// the harness injects a fixture ClinicalApi at the `api` boundary rather than
// cloning the markup.
const PhysicianRoster: React.FC<PhysicianRosterProps> = ({
  api = supabaseClinicalApi,
  now,
  role: roleProp,
  initialSearch = '',
  initialFilter = 'all',
  initialSort = 'recent',
}) => {
  const auth = usePortalAuth();
  const role = roleProp ?? auth.role;
  const canOpen = role === 'physician' || role === 'care_coordinator';
  const nowDate = now ?? new Date();

  const [search, setSearch] = useState(initialSearch);
  const [filter, setFilter] = useState<RosterFilter>(initialFilter);
  const [sort, setSort] = useState<RosterSort>(initialSort);
  const [page, setPage] = useState(0);

  const [rows, setRows] = useState<RosterPatient[] | null>(null);
  const [total, setTotal] = useState(0);
  const [counts, setCounts] = useState<ChipCounts | null>(null);
  const [loadError, setLoadError] = useState(false);

  const load = useCallback(async () => {
    setLoadError(false);
    setRows(null);
    try {
      const result = await api.fetchRoster({
        search: search.trim() || null,
        filter,
        sort,
        limit: PAGE_SIZE,
        offset: page * PAGE_SIZE,
      });
      setRows(result.rows);
      setTotal(result.totalCount);
    } catch {
      setLoadError(true);
    }
  }, [api, search, filter, sort, page]);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    let active = true;
    api
      .fetchChipCounts()
      .then((c) => active && setCounts(c))
      .catch(() => active && setCounts(null));
    return () => {
      active = false;
    };
  }, [api]);

  const chipCounts = counts ?? { all: 0, flagged: 0, missingLabs: 0, questionsWaiting: 0 };
  const isLoading = rows === null && !loadError;
  const hasQuery = search.trim().length > 0;
  const isEmptyRoster = !isLoading && !loadError && !hasQuery && filter === 'all' && total === 0;
  const isNoResults = !isLoading && !loadError && hasQuery && (rows?.length ?? 0) === 0;

  const onPickFilter = (next: RosterFilter) => {
    setFilter(next);
    setPage(0);
  };
  const onSort = (next: RosterSort) => {
    setSort(next);
    setPage(0);
  };
  const clearSearch = () => {
    setSearch('');
    setPage(0);
  };

  return (
    <div className="relative">
      {typeof __PREVIEW_BUILD__ !== 'undefined' && __PREVIEW_BUILD__ && <FictionalDataTag />}

      <h1 className="text-[28px] font-bold leading-tight text-[#030616] dark:text-[#EEF1F8]">Patients</h1>
      <p className="mt-2 text-sm text-[#48556A] dark:text-[#A6B0C3]">
        Everyone enrolled in your Zyndio program. Flags show what needs attention.
      </p>

      {isEmptyRoster ? (
        <EmptyRoster searchValue={search} onSearch={setSearch} />
      ) : (
        <>
          <Toolbar
            search={search}
            onSearch={(v) => {
              setSearch(v);
              setPage(0);
            }}
            onClear={clearSearch}
            filter={filter}
            onFilter={onPickFilter}
            counts={chipCounts}
            sort={sort}
            onSortChange={onSort}
          />

          {loadError && <ErrorPanel onRetry={load} />}

          {!loadError && isLoading && <LoadingTable />}

          {!loadError && isNoResults && <NoResults query={search.trim()} onClear={clearSearch} />}

          {!loadError && !isLoading && !isNoResults && rows && rows.length > 0 && (
            <RosterTable
              rows={rows}
              total={total}
              page={page}
              onPage={setPage}
              canOpen={canOpen}
              now={nowDate}
              filter={filter}
            />
          )}
        </>
      )}
    </div>
  );
};

const Toolbar: React.FC<{
  search: string;
  onSearch: (v: string) => void;
  onClear: () => void;
  filter: RosterFilter;
  onFilter: (f: RosterFilter) => void;
  counts: ChipCounts;
  sort: RosterSort;
  onSortChange: (s: RosterSort) => void;
}> = ({ search, onSearch, onClear, filter, onFilter, counts, sort, onSortChange }) => (
  <div className="mt-6 flex flex-wrap items-center gap-3">
    <div className="relative w-full min-w-[220px] basis-[280px] sm:w-auto sm:flex-1">
      <Search
        className="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400 dark:text-[#8F9AAF]"
        aria-hidden="true"
      />
      <input
        type="search"
        aria-label="Search by name or patient ID"
        placeholder="Search by name or patient ID"
        value={search}
        onChange={(e) => onSearch(e.target.value)}
        className="min-h-[44px] w-full rounded-full border border-slate-300 bg-white pl-11 pr-11 text-sm text-[#030616] placeholder:text-slate-400 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2] dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8] dark:placeholder:text-[#8F9AAF]"
      />
      {search.length > 0 && (
        <button
          type="button"
          onClick={onClear}
          aria-label="Clear search field"
          className="absolute right-1 top-1/2 flex h-11 w-11 -translate-y-1/2 items-center justify-center rounded-full text-slate-500 hover:bg-slate-100 dark:text-[#A6B0C3] dark:hover:bg-[#222838]"
        >
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true">
            <path d="M18 6 6 18M6 6l12 12" />
          </svg>
        </button>
      )}
    </div>

    <div role="radiogroup" aria-label="Filter patients" className="flex flex-wrap items-center gap-2">
      {CHIPS.map((chip) => {
        const selected = filter === chip.key;
        return (
          <button
            key={chip.key}
            type="button"
            role="radio"
            aria-checked={selected}
            onClick={() => onFilter(chip.key)}
            className={`inline-flex min-h-[44px] items-center gap-2 rounded-full px-4 text-sm font-semibold focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2] ${
              selected
                ? 'bg-[#030616] text-white dark:bg-[#EEF1F8] dark:text-[#070A14]'
                : 'border border-slate-300 bg-white text-[#030616] hover:bg-slate-50 dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8] dark:hover:bg-[#222838]'
            }`}
          >
            {chip.label}
            <span className={selected ? 'text-white/80 dark:text-[#070A14]/70' : 'text-slate-500 dark:text-[#A6B0C3]'}>
              {chip.count(counts)}
            </span>
          </button>
        );
      })}
    </div>

    <div className="relative ml-auto inline-flex min-w-0">
      <ArrowDownUp
        className="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-[#48556A] dark:text-[#A6B0C3]"
        aria-hidden="true"
      />
      <select
        aria-label="Sort patients"
        value={sort}
        onChange={(e) => onSortChange(e.target.value as RosterSort)}
        className="h-11 appearance-none rounded-full border border-[#7A86A0] bg-white pl-11 pr-10 text-sm font-semibold text-[#030616] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2] dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8]"
      >
        {SORT_OPTIONS.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
      <svg
        aria-hidden="true"
        className="pointer-events-none absolute right-3 top-1/2 h-[18px] w-[18px] -translate-y-1/2 text-[#48556A] dark:text-[#A6B0C3]"
        viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"
      >
        <path d="M6 9l6 6 6-6" />
      </svg>
    </div>
  </div>
);

const CARD = 'mt-6 overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-[0_1px_2px_#0306160A,0_8px_24px_#2C5CF214] dark:border-[#222838] dark:bg-[#10141F] dark:shadow-none';

const HEADER_ROW = 'grid grid-cols-[1.6fr_0.8fr_1.1fr_1.4fr_1.1fr] xl:grid-cols-[1.8fr_0.8fr_0.8fr_1fr_1.6fr_1fr_44px] items-center gap-4 px-6 py-3 text-xs font-semibold text-slate-500 dark:text-[#A6B0C3]';
const BODY_ROW = 'grid grid-cols-[1.6fr_0.8fr_1.1fr_1.4fr_1.1fr] xl:grid-cols-[1.8fr_0.8fr_0.8fr_1fr_1.6fr_1fr_44px] items-center gap-4 px-6 py-4';

const RosterTable: React.FC<{
  rows: RosterPatient[];
  total: number;
  page: number;
  onPage: (p: number) => void;
  canOpen: boolean;
  now: Date;
  filter: RosterFilter;
}> = ({ rows, total, page, onPage, canOpen, now, filter }) => {
  const start = page * PAGE_SIZE + 1;
  const end = Math.min(total, page * PAGE_SIZE + rows.length);
  const lastPage = Math.max(0, Math.ceil(total / PAGE_SIZE) - 1);

  return (
    <div className={CARD} aria-label="Patients">
      <div className={`${HEADER_ROW} border-b border-slate-200 bg-[#E6ECFA] dark:border-[#222838] dark:bg-[#0B0F19]`}>
        <span>Patient</span>
        <span>Age · Sex</span>
        <span className="hidden xl:block">Program</span>
        <span>Latest lab</span>
        <span>Flags</span>
        <span className="hidden xl:block">Last activity</span>
        <span className="hidden xl:block" aria-hidden="true" />
      </div>

      {rows.map((r) => {
        const week = programWeek(r.programStartedOn, now);
        const cells = (
          <>
            <div className="min-w-0">
              <p className="truncate text-[15px] font-semibold text-[#030616] dark:text-[#EEF1F8]">{r.displayName}</p>
              <p className="truncate text-[13px] tabular-nums text-slate-500 dark:text-[#8F9AAF]">{r.mrn}</p>
            </div>
            <div className="text-sm text-[#48556A] dark:text-[#A6B0C3]">{ageSexShort(r.birthDate, r.sex, now)}</div>
            <div className="hidden text-sm text-[#48556A] dark:text-[#A6B0C3] xl:block">
              {week === null ? '—' : `Week ${week}`}
            </div>
            <div className="text-sm text-[#48556A] dark:text-[#A6B0C3]">
              {r.latestLabAt ? formatMonthDayYear(r.latestLabAt) : 'None yet'}
            </div>
            <div className="flex flex-wrap gap-1.5">
              {r.flags.length === 0 ? (
                <span className="text-sm text-slate-400 dark:text-[#8F9AAF]">None</span>
              ) : (
                r.flags.map((f) => <FlagBadge key={f} flag={f} />)
              )}
            </div>
            <div className="hidden text-sm text-[#48556A] dark:text-[#A6B0C3] xl:block">
              {formatLastActivity(r.lastActivityAt, now)}
            </div>
            <div className="hidden items-center justify-end text-slate-400 xl:flex" aria-hidden="true">
              <ChevronRight className="h-5 w-5" />
            </div>
          </>
        );

        if (canOpen) {
          return (
            <Link
              key={r.patientId}
              to={`/admin/roster/${r.patientId}`}
              state={{ flags: r.flags, openQuestions: r.openQuestions }}
              aria-label={`Open ${r.displayName}`}
              className={`${BODY_ROW} border-b border-slate-100 last:border-0 hover:bg-[#F5F7FD] focus:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-[#2C5CF2] dark:border-[#222838] dark:hover:bg-[#151A27]`}
            >
              {cells}
            </Link>
          );
        }
        return (
          <div key={r.patientId} className={`${BODY_ROW} border-b border-slate-100 last:border-0 dark:border-[#222838]`}>
            {cells}
          </div>
        );
      })}

      <div className="flex items-center justify-between border-t border-slate-200 px-6 py-4 dark:border-[#222838]">
        <div>
          <p className="text-sm text-[#48556A] dark:text-[#A6B0C3]">
            Showing {start}–{end} of {total}
          </p>
          {filter === 'questions_waiting' && (
            <p className="mt-1 text-[13px] text-slate-500 dark:text-[#8F9AAF]">
              Showing patients with a companion question that needs a reply from the care team, oldest first.
            </p>
          )}
        </div>
        <div className="flex items-center gap-2">
          <PagerButton label="Previous page" disabled={page <= 0} onClick={() => onPage(page - 1)}>
            <ChevronLeft className="h-5 w-5" />
          </PagerButton>
          <PagerButton label="Next page" disabled={page >= lastPage} onClick={() => onPage(page + 1)}>
            <ChevronRight className="h-5 w-5" />
          </PagerButton>
        </div>
      </div>
    </div>
  );
};

const PagerButton: React.FC<{ label: string; disabled: boolean; onClick: () => void; children: React.ReactNode }> = ({
  label,
  disabled,
  onClick,
  children,
}) => (
  <button
    type="button"
    aria-label={label}
    disabled={disabled}
    onClick={onClick}
    className="flex h-11 w-11 items-center justify-center rounded-full border border-slate-300 bg-white text-[#030616] hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-40 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2] dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8] dark:hover:bg-[#222838]"
  >
    {children}
  </button>
);

const LoadingTable: React.FC = () => (
  <div className={CARD} aria-busy="true">
    <div className={`${HEADER_ROW} border-b border-slate-200 bg-[#E6ECFA] dark:border-[#222838] dark:bg-[#0B0F19]`}>
      <span>Patient</span>
      <span>Age · Sex</span>
      <span className="hidden xl:block">Program</span>
      <span>Latest lab</span>
      <span>Flags</span>
      <span className="hidden xl:block">Last activity</span>
      <span className="hidden xl:block" aria-hidden="true" />
    </div>
    {Array.from({ length: 8 }).map((_, i) => (
      <div key={i} className={`${BODY_ROW} border-b border-slate-100 last:border-0 dark:border-[#222838]`}>
        <div className="space-y-2">
          <div className="h-4 w-40 rounded bg-slate-200 dark:bg-[#222838]" />
          <div className="h-3 w-24 rounded bg-slate-100 dark:bg-[#1A2130]" />
        </div>
        <div className="h-3 w-12 rounded bg-slate-100 dark:bg-[#1A2130]" />
        <div className="hidden h-3 w-16 rounded bg-slate-100 dark:bg-[#1A2130] xl:block" />
        <div className="h-3 w-20 rounded bg-slate-100 dark:bg-[#1A2130]" />
        <div className="h-5 w-24 rounded-md bg-slate-100 dark:bg-[#1A2130]" />
        <div className="hidden h-3 w-20 rounded bg-slate-100 dark:bg-[#1A2130] xl:block" />
        <div className="hidden xl:block" />
      </div>
    ))}
    <p className="px-6 py-4 text-sm text-slate-500 dark:text-[#A6B0C3]" role="status">
      Loading patients…
    </p>
  </div>
);

const NoResults: React.FC<{ query: string; onClear: () => void }> = ({ query, onClear }) => (
  <div className={`${CARD} p-12 text-center`}>
    <Search className="mx-auto h-6 w-6 text-slate-400 dark:text-[#8F9AAF]" aria-hidden="true" />
    <p className="mt-3 text-[17px] font-semibold text-[#030616] dark:text-[#EEF1F8]">No patients match &quot;{query}&quot;</p>
    <p className="mt-2 text-sm text-[#48556A] dark:text-[#A6B0C3]">
      Check the spelling, or search by patient ID, like ZP-10482.
    </p>
    <button
      type="button"
      onClick={onClear}
      className="mt-5 inline-flex min-h-[44px] items-center rounded-full border border-slate-300 bg-white px-6 text-sm font-semibold text-[#030616] hover:bg-slate-50 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2] dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8] dark:hover:bg-[#222838]"
    >
      Clear search
    </button>
  </div>
);

const EmptyRoster: React.FC<{ searchValue: string; onSearch: (v: string) => void }> = ({ searchValue, onSearch }) => (
  <>
    <div className="mt-6 flex flex-wrap items-center gap-3">
      <div className="relative w-full min-w-[220px] basis-[280px] sm:flex-1">
        <Search className="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400 dark:text-[#8F9AAF]" aria-hidden="true" />
        <input
          type="search"
          aria-label="Search by name or patient ID"
          placeholder="Search by name or patient ID"
          value={searchValue}
          onChange={(e) => onSearch(e.target.value)}
          className="min-h-[44px] w-full rounded-full border border-slate-300 bg-white pl-11 pr-4 text-sm text-[#030616] placeholder:text-slate-400 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2] dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8] dark:placeholder:text-[#8F9AAF]"
        />
      </div>
    </div>
    <div className={`${CARD} p-12 text-center`}>
      <p className="text-[17px] font-semibold text-[#030616] dark:text-[#EEF1F8]">No patients yet</p>
      <p className="mt-2 text-sm text-[#48556A] dark:text-[#A6B0C3]">
        Patients appear here once Zyndio enrolls them in your program. Nothing to do until then.
      </p>
    </div>
  </>
);

const ErrorPanel: React.FC<{ onRetry: () => void }> = ({ onRetry }) => (
  <div className={`${CARD} p-8`} role="alert">
    <p className="text-sm text-[#48556A] dark:text-[#A6B0C3]">
      We couldn&apos;t load your patients. Check your connection and try again. If it keeps happening, contact Zyndio
      support.
    </p>
    <button
      type="button"
      onClick={onRetry}
      className="mt-4 inline-flex min-h-[44px] items-center rounded-full border border-slate-300 bg-white px-6 text-sm font-semibold text-[#030616] hover:bg-slate-50 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2] dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8] dark:hover:bg-[#222838]"
    >
      Try again
    </button>
  </div>
);

export default PhysicianRoster;
