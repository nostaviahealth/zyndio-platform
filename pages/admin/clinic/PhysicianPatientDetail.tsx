import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Link, useLocation, useParams } from 'react-router-dom';
import { ChevronLeft, Upload, FlaskConical, Info, FileText, AlertTriangle } from 'lucide-react';
import {
  ClinicalApi,
  FlagKey,
  LatestResult,
  PatientDetail,
  TrendPeriod,
  TrendPoint,
  supabaseClinicalApi,
} from '../../../lib/clinicalApi';
import FictionalDataTag from '../../../components/ui/FictionalDataTag';
import Tooltip from '../../../components/ui/Tooltip';
import FlagBadge from '../../../components/clinical/FlagBadge';
import TrendChart from '../../../components/clinical/TrendChart';
import CriticalBanner from '../../../components/ui/CriticalBanner';
import {
  STATUS_LABELS,
  formatMonthDay,
  formatMonthDayYear,
  formatValue,
  programWeek,
  ageFromBirthDate,
  sexFull,
} from '../../../lib/clinicalFormat';

// Plain, clinician-approved marker descriptions (not patient data). Keyed by
// analyte_key; markers without one simply show no description line.
const ANALYTE_DESCRIPTIONS: Record<string, string> = {
  hba1c: 'Average blood sugar over the past 2–3 months',
  glucose_fasting: 'Fasting blood sugar',
  insulin_fasting: 'Fasting insulin',
  apob: 'Apolipoprotein B',
  hscrp: 'High-sensitivity C-reactive protein',
  triglycerides: 'Triglycerides',
};

// Report-extraction provenance for a "needs review" value (printed value,
// confidence, report). This lives in the report viewer (TC-016); TC-015 shows
// it only when provided (the preview fixtures supply it so Ava can sign off the
// layout). The live read model doesn't expose it, so the live card shows the
// banner + value + disabled "Check in report" without this block.
export interface ReviewDetail {
  provenance: string; // e.g. "read from page 2 of the report"
  printed: string; // e.g. "1.7 mg/L (smudged)"
  confidence: string; // e.g. "Low"
  report: string; // e.g. "Metabolic panel, Fictional Reference Lab"
}

export interface PhysicianPatientDetailProps {
  api?: ClinicalApi;
  now?: Date;
  mode?: 'light' | 'dark';
  patientId?: string;
  flags?: FlagKey[];
  questionsCount?: number;
  initialSelectedKey?: string;
  initialPeriod?: TrendPeriod;
  reviewDetails?: Record<string, ReviewDetail>;
}

const PERIODS: TrendPeriod[] = ['3M', '6M', '1Y', 'All'];

// 02-patient-detail, Labs tab. Same component backs the live
// /admin/patients/:id route and the /__preview harness (fixtures injected at the
// `api` boundary). open_patient_detail is called exactly once per open.
const PhysicianPatientDetail: React.FC<PhysicianPatientDetailProps> = ({
  api = supabaseClinicalApi,
  now,
  mode = 'light',
  patientId: patientIdProp,
  flags: flagsProp,
  questionsCount: questionsCountProp,
  initialSelectedKey,
  initialPeriod = '6M',
  reviewDetails,
}) => {
  const params = useParams();
  const location = useLocation();
  const patientId = patientIdProp ?? params.id ?? '';
  const navState = (location.state ?? {}) as { flags?: FlagKey[]; openQuestions?: number };
  const flags = flagsProp ?? navState.flags ?? [];
  const questionsCount = questionsCountProp ?? navState.openQuestions;
  const nowDate = now ?? new Date();

  const [detail, setDetail] = useState<PatientDetail | null>(null);
  const [notFound, setNotFound] = useState(false);
  const [latest, setLatest] = useState<LatestResult[] | null>(null);
  const [latestError, setLatestError] = useState(false);
  const [selectedKey, setSelectedKey] = useState<string | undefined>(initialSelectedKey);
  const [period, setPeriod] = useState<TrendPeriod>(initialPeriod);
  const [trend, setTrend] = useState<TrendPoint[] | null>(null);

  const loadLatest = useCallback(async () => {
    setLatestError(false);
    setLatest(null);
    try {
      setLatest(await api.fetchLatestResults(patientId));
    } catch {
      setLatestError(true);
    }
  }, [api, patientId]);

  // open_patient_detail exactly once per patient open. The ref guard survives
  // React StrictMode's double-invoked mount effect (same fiber, ref persists)
  // so the audit RPC fires once. See physician-detail.test.tsx.
  const openedFor = useRef<string | null>(null);
  useEffect(() => {
    if (!patientId || openedFor.current === patientId) return;
    // Guard the audit call with a ref (not a per-run cleanup flag) so React
    // StrictMode's double-invoked mount effect still fires it exactly once AND
    // the single result is applied - a cleanup flag would cancel the only run.
    openedFor.current = patientId;
    (async () => {
      const d = await api.openPatientDetail(patientId);
      if (d === null) {
        setNotFound(true);
        return;
      }
      setDetail(d);
      loadLatest();
    })();
  }, [api, patientId, loadLatest]);

  const selected =
    (latest && selectedKey && latest.find((m) => m.analyteKey === selectedKey)) || latest?.[0] || null;

  useEffect(() => {
    if (!detail || !selected || selected.status === 'needs_review') {
      setTrend(null);
      return;
    }
    let active = true;
    setTrend(null);
    api
      .fetchTrend(detail.patientId, selected.analyteKey, period)
      .then((t) => active && setTrend(t))
      .catch(() => active && setTrend([]));
    return () => {
      active = false;
    };
  }, [api, detail, selected, period]);

  if (notFound) return <NotFound />;
  if (!detail) {
    return (
      <div className="relative">
        {typeof __PREVIEW_BUILD__ !== 'undefined' && __PREVIEW_BUILD__ && <FictionalDataTag />}
        <p className="mt-8 text-sm text-slate-500 dark:text-[#A6B0C3]" role="status">
          Loading…
        </p>
      </div>
    );
  }

  const age = ageFromBirthDate(detail.birthDate, nowDate);
  const week = programWeek(detail.programStartedOn, nowDate);
  const metaParts = [
    detail.mrn,
    age !== null ? String(age) : null,
    sexFull(detail.sex) || null,
    week !== null ? `Week ${week} of program` : null,
  ].filter(Boolean);

  return (
    <div className="relative">
      {typeof __PREVIEW_BUILD__ !== 'undefined' && __PREVIEW_BUILD__ && <FictionalDataTag />}

      <Link
        to="/admin/patients"
        className="inline-flex min-h-[44px] items-center gap-1 text-sm font-semibold text-[#2C5CF2] hover:underline dark:text-[#7C9CFF]"
      >
        <ChevronLeft className="h-4 w-4" aria-hidden="true" />
        Patients
      </Link>

      <div className="mt-1 flex flex-wrap items-start justify-between gap-4">
        <div>
          <div className="flex flex-wrap items-center gap-3">
            <h1 className="text-[28px] font-bold leading-tight text-[#030616] dark:text-[#EEF1F8]">
              {detail.displayName}
            </h1>
            {flags.map((f) => (
              <FlagBadge key={f} flag={f} />
            ))}
          </div>
          <p className="mt-1 text-sm text-[#48556A] dark:text-[#A6B0C3]">{metaParts.join(' · ')}</p>
        </div>
        <DisabledPill
          label="Export data"
          icon={<Upload className="h-4 w-4" aria-hidden="true" />}
          tooltip="Export is coming in the next update."
        />
      </div>

      {detail.treatment && <TreatmentStrip treatment={detail.treatment} />}

      <Tabs questionsCount={questionsCount} />

      {latestError ? (
        <LabsError name={detail.displayName} onRetry={loadLatest} />
      ) : latest === null ? (
        <LabsLoading />
      ) : latest.length === 0 ? (
        <LabsEmpty name={detail.displayName} />
      ) : (
        <div className="mt-6 grid grid-cols-[288px_1fr] gap-4 xl:grid-cols-[360px_1fr] xl:gap-6">
          <MarkerList
            markers={latest}
            selectedKey={selected?.analyteKey}
            onSelect={setSelectedKey}
          />
          {selected && (
            <MarkerDetail
              marker={selected}
              trend={trend}
              period={period}
              onPeriod={setPeriod}
              mode={mode}
              reviewDetail={reviewDetails?.[selected.analyteKey]}
            />
          )}
        </div>
      )}
    </div>
  );
};

const SoonTag: React.FC = () => (
  <span className="ml-2 inline-flex items-center rounded-md bg-[#EEF1F6] px-2 py-0.5 text-xs font-semibold leading-4 text-[#48556A] dark:bg-[#0B0F19] dark:text-[#A6B0C3]">
    Soon
  </span>
);

const DisabledPill: React.FC<{ label: string; icon?: React.ReactNode; tooltip: string }> = ({
  label,
  icon,
  tooltip,
}) => (
  <Tooltip label={tooltip}>
    <button
      type="button"
      aria-disabled="true"
      className="inline-flex min-h-[44px] cursor-not-allowed items-center gap-2 rounded-full border border-slate-300 bg-white px-6 text-sm font-semibold text-[#030616] opacity-60 dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8]"
      onClick={(e) => e.preventDefault()}
    >
      {icon}
      {label}
      <SoonTag />
    </button>
  </Tooltip>
);

const TreatmentStrip: React.FC<{ treatment: NonNullable<PatientDetail['treatment']> }> = ({ treatment }) => (
  <div className="mt-6 flex flex-wrap gap-x-10 gap-y-3 rounded-2xl border border-slate-200 bg-white px-5 py-3 dark:border-[#222838] dark:bg-[#10141F]">
    <Field label="Treatment" value={treatment.name} strong />
    <Field label="Started" value={formatMonthDayYear(treatment.startedOn)} />
    <Field label="Status" value={treatment.status ?? ''} />
    {/* Source hidden below 1280 (specs responsive frame). Never a dose. */}
    <div className="hidden xl:block">
      <Field label="Source" value={treatment.source ?? ''} />
    </div>
  </div>
);

const Field: React.FC<{ label: string; value: string; strong?: boolean }> = ({ label, value, strong }) => (
  <div>
    <p className="text-[13px] text-slate-500 dark:text-[#8F9AAF]">{label}</p>
    <p className={`text-[15px] text-[#030616] dark:text-[#EEF1F8] ${strong ? 'font-semibold' : ''}`}>{value}</p>
  </div>
);

const DISABLED_TAB_TOOLTIPS: Record<string, string> = {
  Timeline: 'Timeline is coming in the next update.',
  'Pre-visit brief': 'Pre-visit briefs are coming in the next update.',
};

const Tabs: React.FC<{ questionsCount?: number }> = ({ questionsCount }) => {
  const questionsLabel =
    questionsCount && questionsCount > 0 ? `Questions and notes (${questionsCount})` : 'Questions and notes';
  return (
    <div role="tablist" aria-label="Patient sections" className="mt-6 flex gap-6 border-b border-slate-200 dark:border-[#222838]">
      <span
        role="tab"
        aria-selected="true"
        className="relative -mb-px inline-flex min-h-[44px] items-center border-b-[3px] border-[#2C5CF2] px-1 text-[15px] font-semibold text-[#030616] dark:border-[#7C9CFF] dark:text-[#EEF1F8]"
      >
        Labs
      </span>
      <span
        role="tab"
        aria-selected="false"
        aria-disabled="true"
        className="relative -mb-px inline-flex min-h-[44px] cursor-not-allowed items-center px-1 text-[15px] font-semibold text-slate-400 dark:text-[#6C7690]"
      >
        {questionsLabel}
      </span>
      {['Timeline', 'Pre-visit brief'].map((t) => (
        <Tooltip key={t} label={DISABLED_TAB_TOOLTIPS[t]}>
          <span
            role="tab"
            aria-selected="false"
            aria-disabled="true"
            tabIndex={0}
            className="relative -mb-px inline-flex min-h-[44px] cursor-not-allowed items-center px-1 text-[15px] font-semibold text-slate-400 dark:text-[#6C7690]"
          >
            {t}
            <SoonTag />
          </span>
        </Tooltip>
      ))}
    </div>
  );
};

const MarkerList: React.FC<{
  markers: LatestResult[];
  selectedKey?: string;
  onSelect: (k: string) => void;
}> = ({ markers, selectedKey, onSelect }) => (
  <div className="h-fit overflow-hidden rounded-2xl border border-slate-200 bg-white dark:border-[#222838] dark:bg-[#10141F]">
    <p className="border-b border-slate-100 px-4 py-3 text-[13px] font-semibold uppercase tracking-wide text-slate-500 dark:border-[#222838] dark:text-[#A6B0C3]">
      Latest results · {markers.length} {markers.length === 1 ? 'marker' : 'markers'}
    </p>
    <ul>
      {markers.map((m) => {
        const active = m.analyteKey === selectedKey;
        return (
          <li key={m.analyteKey}>
            <button
              type="button"
              aria-current={active ? 'true' : undefined}
              onClick={() => onSelect(m.analyteKey)}
              className={`flex min-h-[64px] w-full items-center justify-between gap-3 border-b border-slate-100 px-4 py-2.5 text-left last:border-0 focus:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-[#2C5CF2] dark:border-[#222838] ${
                active ? 'bg-[#EFF4FF] dark:bg-[#18224A]' : 'hover:bg-[#F5F7FD] dark:hover:bg-[#151A27]'
              }`}
            >
              <span className="min-w-0">
                <span className="block truncate text-[15px] font-semibold text-[#030616] dark:text-[#EEF1F8]">
                  {m.analyteLabel}
                </span>
                <MarkerStatusBadge marker={m} />
              </span>
              <span className="shrink-0 text-right">
                <span className="text-[17px] font-semibold tabular-nums text-[#030616] dark:text-[#EEF1F8]">
                  {formatValue(m.value)}
                </span>{' '}
                <span className="text-[13px] text-slate-500 dark:text-[#8F9AAF]">{m.unit}</span>
                <span className="block text-[13px] text-slate-500 dark:text-[#8F9AAF]">{formatMonthDay(m.takenAt)}</span>
              </span>
            </button>
          </li>
        );
      })}
    </ul>
  </div>
);

function statusTone(status: LatestResult['status']): string {
  if (status === 'needs_review') return 'bg-[#FCEFD6] text-[#8A4F00] dark:bg-[#2F220D] dark:text-[#F2B65A]';
  if (status === 'outside_range') return 'bg-[#FCEFD6] text-[#8A4F00] dark:bg-[#2F220D] dark:text-[#F2B65A]';
  if (status === 'within_range' || status === 'baseline')
    return 'bg-[#E8EDFD] text-[#2C5CF2] dark:bg-[#18224A] dark:text-[#AFC3FF]';
  return 'bg-[#EEF1F6] text-[#48556A] dark:bg-[#0B0F19] dark:text-[#A6B0C3]';
}

const MarkerStatusBadge: React.FC<{ marker: LatestResult }> = ({ marker }) => (
  <span className={`mt-1 inline-flex items-center rounded-md px-2 py-0.5 text-xs font-semibold ${statusTone(marker.status)}`}>
    {STATUS_LABELS[marker.status]}
  </span>
);

const CARD = 'rounded-2xl border border-slate-200 bg-white p-6 dark:border-[#222838] dark:bg-[#10141F] xl:p-6';

const MarkerDetail: React.FC<{
  marker: LatestResult;
  trend: TrendPoint[] | null;
  period: TrendPeriod;
  onPeriod: (p: TrendPeriod) => void;
  mode: 'light' | 'dark';
  reviewDetail?: ReviewDetail;
}> = ({ marker, trend, period, onPeriod, mode, reviewDetail }) => {
  const description = ANALYTE_DESCRIPTIONS[marker.analyteKey];
  const isNeedsReview = marker.status === 'needs_review';

  return (
    <div className={CARD}>
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 className="text-xl font-bold text-[#030616] dark:text-[#EEF1F8]">{marker.analyteLabel}</h2>
          {description && <p className="mt-1 text-sm text-[#48556A] dark:text-[#A6B0C3]">{description}</p>}
        </div>
        {!isNeedsReview && (
          <div role="group" aria-label="Trend period" className="inline-flex rounded-full bg-[#EEF1F6] p-1 dark:bg-[#0B0F19]">
            {PERIODS.map((p) => (
              <button
                key={p}
                type="button"
                aria-pressed={period === p}
                onClick={() => onPeriod(p)}
                className={`min-h-[36px] rounded-full px-4 text-sm font-semibold focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2] ${
                  period === p
                    ? 'bg-white text-[#030616] shadow-sm dark:bg-[#222838] dark:text-[#EEF1F8]'
                    : 'text-slate-500 dark:text-[#A6B0C3]'
                }`}
              >
                {p}
              </button>
            ))}
          </div>
        )}
      </div>

      {isNeedsReview ? (
        <NeedsReviewBody marker={marker} detail={reviewDetail} />
      ) : (
        <TrendBody marker={marker} trend={trend} mode={mode} />
      )}
    </div>
  );
};

const CAVEAT = (
  <div className="mt-5 flex gap-3 rounded-xl border border-slate-200 bg-[#F8FAFF] p-4 dark:border-[#222838] dark:bg-[#0B0F19]">
    <Info className="mt-0.5 h-5 w-5 shrink-0 text-slate-400 dark:text-[#8F9AAF]" aria-hidden="true" />
    <p className="text-[13px] text-[#48556A] dark:text-[#A6B0C3]">
      General default range, for demo use only. Zyndio&apos;s physician lead sets the ranges used for care. Until then,
      patients see the same caveat in the app.
    </p>
  </div>
);

const TrendBody: React.FC<{ marker: LatestResult; trend: TrendPoint[] | null; mode: 'light' | 'dark' }> = ({
  marker,
  trend,
  mode,
}) => {
  const points = trend ?? [];
  const multi = points.length >= 2;

  let meta: string;
  if (points.length <= 1) {
    meta = `${formatMonthDayYear(marker.takenAt)} · first result`;
  } else {
    const base = points[0];
    const last = points[points.length - 1];
    const delta = (last.value ?? 0) - (base.value ?? 0);
    const sign = delta < 0 ? '−' : '+';
    meta = `${formatMonthDayYear(marker.takenAt)} · ${sign}${Math.abs(delta).toFixed(1)} points since baseline (${formatMonthDay(base.takenAt)})`;
  }

  return (
    <>
      <div className="mt-4 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-end gap-2">
          <span className="text-[40px] font-bold leading-none tabular-nums text-[#030616] dark:text-[#EEF1F8]">
            {formatValue(marker.value)}
          </span>
          <span className="pb-1 text-base text-slate-500 dark:text-[#8F9AAF]">{marker.unit}</span>
        </div>
        <MarkerStatusBadge marker={marker} />
      </div>
      <p className="mt-2 text-[13px] text-[#48556A] dark:text-[#A6B0C3]">{meta}</p>

      {multi ? (
        <TrendChart points={points} analyteLabel={marker.analyteLabel} unit={marker.unit} mode={mode} />
      ) : (
        <div className="mt-5 flex flex-col items-center justify-center rounded-xl border border-slate-200 px-6 py-12 text-center dark:border-[#222838]">
          <FlaskConical className="h-6 w-6 text-slate-400 dark:text-[#8F9AAF]" aria-hidden="true" />
          <p className="mt-3 text-[17px] font-semibold text-[#030616] dark:text-[#EEF1F8]">One result so far</p>
          <p className="mt-1 text-sm text-[#48556A] dark:text-[#A6B0C3]">
            A trend appears when the next {marker.analyteLabel} result arrives.
          </p>
        </div>
      )}

      {CAVEAT}

      {multi && (
        <div className="mt-4 divide-y divide-slate-100 dark:divide-[#222838]">
          {[...points].reverse().map((p, i) => (
            <div key={i} className="flex items-center justify-between gap-4 py-3 text-sm">
              <span className="text-[#48556A] dark:text-[#A6B0C3]">{formatMonthDayYear(p.takenAt)}</span>
              <span className="flex-1 text-[#030616] dark:text-[#EEF1F8]">
                <span className="font-semibold tabular-nums">{formatValue(p.value)}</span> {p.unit}
                {p.originalValue !== null && (
                  <span className="ml-2 text-[13px] text-slate-500 dark:text-[#8F9AAF]">was {formatValue(p.originalValue)}</span>
                )}
              </span>
              <span
                aria-disabled="true"
                className="cursor-not-allowed font-semibold text-[#2C5CF2] opacity-50 dark:text-[#7C9CFF]"
              >
                View report
                <SoonTag />
              </span>
            </div>
          ))}
        </div>
      )}
    </>
  );
};

const NeedsReviewBody: React.FC<{ marker: LatestResult; detail?: ReviewDetail }> = ({ marker, detail }) => (
  <>
    <div className="mt-4 flex flex-wrap items-center justify-between gap-3">
      <div className="flex items-end gap-2">
        <span className="text-[40px] font-bold leading-none tabular-nums text-[#030616] dark:text-[#EEF1F8]">
          {formatValue(marker.value)}
        </span>
        <span className="pb-1 text-base text-slate-500 dark:text-[#8F9AAF]">{marker.unit}</span>
      </div>
      <MarkerStatusBadge marker={marker} />
    </div>
    <p className="mt-2 text-[13px] text-[#48556A] dark:text-[#A6B0C3]">
      {formatMonthDayYear(marker.takenAt)}
      {detail ? ` · ${detail.provenance}` : ''}
    </p>

    <div className="mt-5 flex gap-3 rounded-xl border border-[#F2B65A]/50 bg-[#FCEFD6] p-4 dark:border-[#F2B65A]/40 dark:bg-[#2F220D]">
      <AlertTriangle className="mt-0.5 h-5 w-5 shrink-0 text-[#8A4F00] dark:text-[#F2B65A]" aria-hidden="true" />
      <p className="text-sm text-[#8A4F00] dark:text-[#F2B65A]">
        This value was hard to read, so it isn&apos;t used in trends or outcomes until someone checks it against the
        report.
      </p>
    </div>

    {/* "Check in report" opens the TC-016 report viewer - disabled here, with
        the same neutral Soon tag as the other entry points (Ava, TC-015 notes). */}
    <button
      type="button"
      disabled
      aria-disabled="true"
      className="mt-5 inline-flex min-h-[44px] cursor-not-allowed items-center gap-2 rounded-full bg-[#2C5CF2] px-6 text-sm font-semibold text-white opacity-60 dark:bg-[#7C9CFF] dark:text-[#030616]"
    >
      <FileText className="h-4 w-4" aria-hidden="true" />
      Check in report
      <SoonTag />
    </button>

    {detail && (
      <dl className="mt-6 space-y-2 text-sm">
        <ProvRow label="Printed on report" value={detail.printed} />
        <ProvRow label="Confidence" value={detail.confidence} />
        <ProvRow label="Report" value={detail.report} />
      </dl>
    )}
  </>
);

const ProvRow: React.FC<{ label: string; value: string }> = ({ label, value }) => (
  <div className="flex gap-6">
    <dt className="w-36 shrink-0 text-slate-500 dark:text-[#8F9AAF]">{label}</dt>
    <dd className="text-[#030616] dark:text-[#EEF1F8]">{value}</dd>
  </div>
);

const LabsLoading: React.FC = () => (
  <div className="mt-6 grid grid-cols-[288px_1fr] gap-4 xl:grid-cols-[360px_1fr] xl:gap-6" aria-busy="true">
    <div className="h-80 rounded-2xl border border-slate-200 bg-white dark:border-[#222838] dark:bg-[#10141F]" />
    <div className="h-80 rounded-2xl border border-slate-200 bg-white dark:border-[#222838] dark:bg-[#10141F]" />
    <p className="sr-only" role="status">
      Loading lab results…
    </p>
  </div>
);

const LabsEmpty: React.FC<{ name: string }> = ({ name }) => {
  const first = name.split(' ')[0];
  return (
    <div className="mt-6 rounded-2xl border border-slate-200 bg-white p-12 text-center dark:border-[#222838] dark:bg-[#10141F]">
      <FlaskConical className="mx-auto h-6 w-6 text-slate-400 dark:text-[#8F9AAF]" aria-hidden="true" />
      <p className="mt-3 text-[17px] font-semibold text-[#030616] dark:text-[#EEF1F8]">No lab results yet</p>
      <p className="mx-auto mt-2 max-w-md text-sm text-[#48556A] dark:text-[#A6B0C3]">
        {first} hasn&apos;t added a lab report. Reports they upload in the Zyndio app appear here after the values are
        read and checked.
      </p>
    </div>
  );
};

const LabsError: React.FC<{ name: string; onRetry: () => void }> = ({ name, onRetry }) => {
  const first = name.split(' ')[0];
  return (
    <div className="mt-6 rounded-2xl border border-slate-200 bg-white p-8 dark:border-[#222838] dark:bg-[#10141F]">
      <CriticalBanner>
        We couldn&apos;t load {first}&apos;s lab results. Check your connection and try again. Nothing has changed in
        the record.
      </CriticalBanner>
      <button
        type="button"
        onClick={onRetry}
        className="mt-4 inline-flex min-h-[44px] items-center rounded-full border border-slate-300 bg-white px-6 text-sm font-semibold text-[#030616] hover:bg-slate-50 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2] dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8] dark:hover:bg-[#222838]"
      >
        Try again
      </button>
    </div>
  );
};

// Invisible / other-clinic / unknown id all land here - one state for every
// case (wrong link, patient left the program, another clinic's patient, no
// access). It never hints whether the patient exists. Copy per Ava's TC-015
// additions (handoff/physician/README.md).
// Ava's TC-015 notes: one heading only. Her card title is the page's single
// heading; "Patient not found" is the document title (restored on unmount).
const NotFound: React.FC = () => {
  useEffect(() => {
    const previous = document.title;
    document.title = 'Patient not found';
    return () => {
      document.title = previous;
    };
  }, []);
  return (
    <div className="relative">
      {typeof __PREVIEW_BUILD__ !== 'undefined' && __PREVIEW_BUILD__ && <FictionalDataTag />}
      <Link
        to="/admin/patients"
        className="inline-flex min-h-[44px] items-center gap-1 text-sm font-semibold text-[#2C5CF2] hover:underline dark:text-[#7C9CFF]"
      >
        <ChevronLeft className="h-4 w-4" aria-hidden="true" />
        Patients
      </Link>
      <div className="mt-6 rounded-2xl border border-slate-200 bg-white p-12 text-center dark:border-[#222838] dark:bg-[#10141F]">
        <h1 className="text-[17px] font-semibold text-[#030616] dark:text-[#EEF1F8]">We can&apos;t show this patient</h1>
        <p className="mx-auto mt-2 max-w-md text-sm text-[#48556A] dark:text-[#A6B0C3]">
          The link may be wrong, or they&apos;re no longer in your clinic&apos;s program.
        </p>
        <Link
          to="/admin/patients"
          className="mt-5 inline-flex min-h-[44px] items-center rounded-full bg-[#2C5CF2] px-6 text-sm font-semibold text-white hover:bg-[#2449C9] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2] dark:bg-[#7C9CFF] dark:text-[#030616] dark:hover:bg-[#6487EC]"
        >
          Back to Patients
        </Link>
      </div>
    </div>
  );
};

export default PhysicianPatientDetail;
