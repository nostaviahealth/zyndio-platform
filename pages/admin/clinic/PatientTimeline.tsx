import React, { useCallback, useEffect, useState } from 'react';
import { CalendarClock, ChevronDown, ChevronRight, RotateCw } from 'lucide-react';
import { PatientRecordApi, TimelineEvent } from '../../../lib/patientRecordApi';
import { eventSummary, eventTitle, sourceLabel } from '../../../lib/timelineFormat';
import { formatMonthDayYear, formatValue, statusLabel } from '../../../lib/clinicalFormat';
import CriticalBanner from '../../../components/ui/CriticalBanner';

const PAGE = 200;

// POR-03 Timeline tab: one newest-first list over every registered source
// (patient_timeline). Lab events expand to their values; nothing here is
// editable.
const PatientTimeline: React.FC<{ api: PatientRecordApi; patientId: string; name: string }> = ({
  api,
  patientId,
  name,
}) => {
  const [events, setEvents] = useState<TimelineEvent[] | null>(null);
  const [error, setError] = useState(false);
  const [hasMore, setHasMore] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [open, setOpen] = useState<Record<string, boolean>>({});

  const load = useCallback(async () => {
    setError(false);
    setEvents(null);
    try {
      const page = await api.fetchTimeline(patientId, null, PAGE);
      setEvents(page);
      setHasMore(page.length === PAGE);
    } catch {
      setError(true);
    }
  }, [api, patientId]);

  useEffect(() => {
    load();
  }, [load]);

  const loadMore = async () => {
    if (!events || events.length === 0) return;
    setLoadingMore(true);
    try {
      const page = await api.fetchTimeline(patientId, events[events.length - 1].occurredAt, PAGE);
      setEvents([...events, ...page]);
      setHasMore(page.length === PAGE);
    } catch {
      setError(true);
    } finally {
      setLoadingMore(false);
    }
  };

  const first = name.split(' ')[0];

  if (error) {
    return (
      <div className="mt-6 rounded-2xl border border-slate-200 bg-white p-8 dark:border-[#222838] dark:bg-[#10141F]">
        <CriticalBanner>
          We couldn&apos;t load {first}&apos;s timeline. Check your connection and try again. Nothing has changed in the
          record.
        </CriticalBanner>
        <button type="button" onClick={load} className={SECONDARY_BUTTON}>
          <RotateCw className="h-4 w-4" aria-hidden="true" />
          Try again
        </button>
      </div>
    );
  }

  if (events === null) {
    return (
      <div className="mt-6 h-80 rounded-2xl border border-slate-200 bg-white dark:border-[#222838] dark:bg-[#10141F]" aria-busy="true">
        <p className="sr-only" role="status">
          Loading timeline…
        </p>
      </div>
    );
  }

  if (events.length === 0) {
    return (
      <div className="mt-6 rounded-2xl border border-slate-200 bg-white p-12 text-center dark:border-[#222838] dark:bg-[#10141F]">
        <CalendarClock className="mx-auto h-6 w-6 text-slate-400 dark:text-[#8F9AAF]" aria-hidden="true" />
        <p className="mt-3 text-[17px] font-semibold text-[#030616] dark:text-[#EEF1F8]">Nothing on the timeline yet</p>
        <p className="mx-auto mt-2 max-w-md text-sm text-[#48556A] dark:text-[#A6B0C3]">
          Lab reports, treatment and visits for {first} appear here as they are recorded.
        </p>
      </div>
    );
  }

  return (
    <div className="mt-6 rounded-2xl border border-slate-200 bg-white dark:border-[#222838] dark:bg-[#10141F]">
      <h2 className="sr-only">Timeline</h2>
      <ol aria-label={`Timeline for ${name}`}>
        {events.map((e) => {
          const key = `${e.source}:${e.refId ?? ''}:${e.occurredAt}`;
          const results = e.detail.results ?? [];
          const expandable = results.length > 0;
          const isOpen = !!open[key];
          const summary = eventSummary(e);
          return (
            <li key={key} className="border-b border-slate-100 px-5 py-4 last:border-0 dark:border-[#222838]">
              <div className="flex gap-5">
                <p className="w-28 shrink-0 text-[13px] tabular-nums text-[#48556A] dark:text-[#A6B0C3]">
                  {formatMonthDayYear(e.occurredAt)}
                </p>
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="inline-flex items-center rounded-md bg-[#EEF1F6] px-2 py-0.5 text-xs font-semibold text-[#48556A] dark:bg-[#0B0F19] dark:text-[#A6B0C3]">
                      {sourceLabel(e.source)}
                    </span>
                    {expandable ? (
                      <button
                        type="button"
                        aria-expanded={isOpen}
                        onClick={() => setOpen({ ...open, [key]: !isOpen })}
                        className="inline-flex min-h-[32px] items-center gap-1 rounded text-left text-[15px] font-semibold text-[#030616] hover:underline focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2] dark:text-[#EEF1F8]"
                      >
                        {isOpen ? (
                          <ChevronDown className="h-4 w-4" aria-hidden="true" />
                        ) : (
                          <ChevronRight className="h-4 w-4" aria-hidden="true" />
                        )}
                        {eventTitle(e)}
                      </button>
                    ) : (
                      <span className="text-[15px] font-semibold text-[#030616] dark:text-[#EEF1F8]">{eventTitle(e)}</span>
                    )}
                    {(e.status === 'outside_range' || e.status === 'needs_review') && (
                      <span className="inline-flex items-center rounded-md bg-[#FCEFD6] px-2 py-0.5 text-xs font-semibold text-[#8A4F00] dark:bg-[#2F220D] dark:text-[#F2B65A]">
                        {e.status === 'outside_range' ? 'Outside range' : 'Needs review'}
                      </span>
                    )}
                  </div>
                  {summary && <p className="mt-1 text-sm text-[#48556A] dark:text-[#A6B0C3]">{summary}</p>}
                  {expandable && isOpen && (
                    <table className="mt-3 w-full text-sm">
                      <thead className="sr-only">
                        <tr>
                          <th>Marker</th>
                          <th>Value</th>
                          <th>Status</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-slate-100 dark:divide-[#222838]">
                        {results.map((r) => (
                          <tr key={r.analyteKey}>
                            <td className="py-2 pr-4 text-[#030616] dark:text-[#EEF1F8]">{r.analyteLabel}</td>
                            <td className="py-2 pr-4 tabular-nums text-[#030616] dark:text-[#EEF1F8]">
                              {formatValue(r.value)} {r.unit}
                              {r.originalValue !== null && (
                                <span className="ml-2 text-[13px] text-slate-500 dark:text-[#8F9AAF]">
                                  was {formatValue(r.originalValue)}
                                </span>
                              )}
                            </td>
                            <td className="py-2 text-[13px] text-[#48556A] dark:text-[#A6B0C3]">
                              {statusLabel(r.status, r.rangeSource)}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  )}
                </div>
              </div>
            </li>
          );
        })}
      </ol>
      {hasMore && (
        <div className="border-t border-slate-100 px-5 py-4 dark:border-[#222838]">
          <button type="button" onClick={loadMore} disabled={loadingMore} className={SECONDARY_BUTTON}>
            {loadingMore ? 'Loading…' : 'Show older events'}
          </button>
        </div>
      )}
    </div>
  );
};

export const SECONDARY_BUTTON =
  'mt-4 inline-flex min-h-[44px] items-center gap-2 rounded-full border border-slate-300 bg-white px-6 text-sm font-semibold text-[#030616] hover:bg-slate-50 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2] disabled:cursor-not-allowed disabled:opacity-60 dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8] dark:hover:bg-[#222838]';

export default PatientTimeline;
