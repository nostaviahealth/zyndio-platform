import React, { useCallback, useEffect, useState } from 'react';
import { CalendarCheck, RotateCw } from 'lucide-react';
import { PatientRecordApi, PrevisitBrief as Brief } from '../../../lib/patientRecordApi';
import { briefSections, sinceLine, summaryLine, treatmentLine } from '../../../lib/previsitBrief';
import { formatMonthDayYear } from '../../../lib/clinicalFormat';
import CriticalBanner from '../../../components/ui/CriticalBanner';
import { SECONDARY_BUTTON } from './PatientTimeline';

// POR-04 Pre-visit brief tab. Structured facts from patient_previsit_brief,
// rendered ONLY through the fixed templates in lib/previsitBrief.ts - no free
// text, no AI text. Physician / care coordinator can mark a visit as done
// today, which moves the brief's "since" date forward.
const PrevisitBrief: React.FC<{
  api: PatientRecordApi;
  patientId: string;
  name: string;
  canRecordVisit: boolean;
}> = ({ api, patientId, name, canRecordVisit }) => {
  const [brief, setBrief] = useState<Brief | null>(null);
  const [state, setState] = useState<'loading' | 'ready' | 'error' | 'not-found'>('loading');
  const [recording, setRecording] = useState(false);
  const [visitError, setVisitError] = useState(false);

  const load = useCallback(async () => {
    setState('loading');
    try {
      const b = await api.fetchBrief(patientId);
      setBrief(b);
      setState(b ? 'ready' : 'not-found');
    } catch {
      setState('error');
    }
  }, [api, patientId]);

  useEffect(() => {
    load();
  }, [load]);

  const recordVisit = async () => {
    setRecording(true);
    setVisitError(false);
    try {
      await api.recordVisit(patientId, null);
      await load();
    } catch {
      setVisitError(true);
    } finally {
      setRecording(false);
    }
  };

  const first = name.split(' ')[0];

  if (state === 'error' || state === 'not-found') {
    return (
      <div className="mt-6 rounded-2xl border border-slate-200 bg-white p-8 dark:border-[#222838] dark:bg-[#10141F]">
        <CriticalBanner>
          We couldn&apos;t build {first}&apos;s pre-visit brief. Check your connection and try again. Nothing has
          changed in the record.
        </CriticalBanner>
        <button type="button" onClick={load} className={SECONDARY_BUTTON}>
          <RotateCw className="h-4 w-4" aria-hidden="true" />
          Try again
        </button>
      </div>
    );
  }

  if (state === 'loading' || !brief) {
    return (
      <div className="mt-6 h-80 rounded-2xl border border-slate-200 bg-white dark:border-[#222838] dark:bg-[#10141F]" aria-busy="true">
        <p className="sr-only" role="status">
          Loading pre-visit brief…
        </p>
      </div>
    );
  }

  const treatment = treatmentLine(brief);

  return (
    <div className="mt-6 rounded-2xl border border-slate-200 bg-white p-6 dark:border-[#222838] dark:bg-[#10141F]">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-[#030616] dark:text-[#EEF1F8]">Pre-visit brief</h2>
          <p className="mt-1 text-sm text-[#48556A] dark:text-[#A6B0C3]">{sinceLine(brief)}</p>
          <p className="mt-1 text-sm text-[#48556A] dark:text-[#A6B0C3]">{summaryLine(brief)}</p>
          {treatment && <p className="mt-1 text-sm text-[#48556A] dark:text-[#A6B0C3]">{treatment}</p>}
        </div>
        {canRecordVisit && (
          <button
            type="button"
            onClick={recordVisit}
            disabled={recording}
            className="inline-flex min-h-[44px] items-center gap-2 rounded-full border border-slate-300 bg-white px-6 text-sm font-semibold text-[#030616] hover:bg-slate-50 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2] disabled:cursor-not-allowed disabled:opacity-60 dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8] dark:hover:bg-[#222838]"
          >
            <CalendarCheck className="h-4 w-4" aria-hidden="true" />
            {recording ? 'Saving…' : 'Mark visit done today'}
          </button>
        )}
      </div>
      {visitError && (
        <div className="mt-4">
          <CriticalBanner>We couldn&apos;t save the visit. Try again. Nothing has changed in the record.</CriticalBanner>
        </div>
      )}

      <div className="mt-6 grid gap-4 lg:grid-cols-2">
        {briefSections(brief).map((s) => (
          <section
            key={s.id}
            aria-labelledby={`brief-${s.id}`}
            className="rounded-xl border border-slate-200 p-4 dark:border-[#222838]"
          >
            <h3 id={`brief-${s.id}`} className="text-[13px] font-semibold uppercase tracking-wide text-slate-500 dark:text-[#A6B0C3]">
              {s.heading}
            </h3>
            {s.lines.length === 0 ? (
              <p className="mt-2 text-sm text-[#48556A] dark:text-[#A6B0C3]">{s.empty}</p>
            ) : (
              <ul className="mt-2 list-disc space-y-1.5 pl-5 text-sm text-[#030616] dark:text-[#EEF1F8]">
                {s.lines.map((l, i) => (
                  <li key={i}>{l}</li>
                ))}
              </ul>
            )}
          </section>
        ))}
      </div>

      <p className="mt-5 text-[13px] text-slate-500 dark:text-[#8F9AAF]">
        Built from the record with fixed wording on {formatMonthDayYear(brief.generatedAt)}. No AI-written text.
      </p>
    </div>
  );
};

export default PrevisitBrief;
