import React, { useCallback, useEffect, useState } from 'react';
import { Info, Plus, Activity } from 'lucide-react';
import {
  PatientTreatmentContext,
  TreatmentApi,
  TreatmentCourseStatus,
  TreatmentEventType,
  supabaseTreatmentApi,
} from '../../lib/treatmentApi';

export interface TreatmentContextPanelProps {
  patientId: string;
  canEdit?: boolean;
  api?: TreatmentApi;
}

const EVENT_TYPE_LABELS: Record<TreatmentEventType, string> = {
  medication_start: 'Medication start',
  dose_change: 'Dose change',
  status_change: 'Status change',
  tolerability_note: 'Tolerability note',
  clinician_change: 'Clinician change',
};

const STATUS_LABELS: Record<TreatmentCourseStatus, string> = {
  active: 'Active',
  paused: 'Paused',
  discontinued: 'Discontinued',
  completed: 'Completed',
};

function statusBadgeClass(status: TreatmentCourseStatus): string {
  switch (status) {
    case 'active':
      return 'bg-[#E3F5EC] text-[#15784A] dark:bg-[#0F2A1D] dark:text-[#5FD39A]';
    case 'paused':
      return 'bg-[#FCEFD6] text-[#8A4F00] dark:bg-[#2F220D] dark:text-[#F2B65A]';
    case 'discontinued':
      return 'bg-[#FCE8E6] text-[#B42318] dark:bg-[#3A1614] dark:text-[#FF8F86]';
    case 'completed':
      return 'bg-[#E8EDFD] text-[#2C5CF2] dark:bg-[#18224A] dark:text-[#AFC3FF]';
  }
}

export const TreatmentContextPanel: React.FC<TreatmentContextPanelProps> = ({
  patientId,
  canEdit = false,
  api = supabaseTreatmentApi,
}) => {
  const [context, setContext] = useState<PatientTreatmentContext | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [showForm, setShowForm] = useState<boolean>(false);
  const [eventType, setEventType] = useState<TreatmentEventType>('medication_start');
  const [medication, setMedication] = useState<string>('');
  const [formulation, setFormulation] = useState<string>('');
  const [doseValue, setDoseValue] = useState<string>('');
  const [doseUnit, setDoseUnit] = useState<string>('mg weekly');
  const [statusValue, setStatusValue] = useState<TreatmentCourseStatus>('active');
  const [note, setNote] = useState<string>('');
  const [submitting, setSubmitting] = useState<boolean>(false);
  const [formError, setFormError] = useState<string | null>(null);

  const loadContext = useCallback(async () => {
    setLoading(true);
    setLoadError(null);
    try {
      const res = await api.fetchTreatmentContext(patientId);
      setContext(res);
      if (res?.course) {
        setEventType('dose_change');
      } else {
        setEventType('medication_start');
      }
    } catch (err) {
      setLoadError(err instanceof Error ? err.message : 'Unable to load treatment context.');
    } finally {
      setLoading(false);
    }
  }, [api, patientId]);

  useEffect(() => {
    if (patientId) {
      loadContext();
    }
  }, [patientId, loadContext]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormError(null);

    const needsMedication = eventType === 'medication_start' || !context?.course;
    if (needsMedication && !medication.trim()) {
      setFormError('Medication name is required to start a treatment course.');
      return;
    }

    let parsedDose: number | null = null;
    if (doseValue.trim() !== '') {
      const num = Number(doseValue);
      if (!Number.isFinite(num) || num <= 0) {
        setFormError('Recorded dose must be a positive number.');
        return;
      }
      parsedDose = num;
    } else if (eventType === 'dose_change') {
      setFormError('Recorded dose value is required for a dose change event.');
      return;
    }

    if (eventType === 'tolerability_note' && !note.trim()) {
      setFormError('Please enter a tolerability note.');
      return;
    }

    setSubmitting(true);
    try {
      await api.recordTreatmentEvent({
        patientId,
        eventType,
        medication: medication.trim() || null,
        formulation: formulation.trim(),
        doseValue: parsedDose,
        doseUnit: parsedDose !== null ? doseUnit.trim() || 'mg weekly' : null,
        statusValue:
          eventType === 'status_change' || eventType === 'medication_start' ? statusValue : null,
        note: note.trim() || null,
      });
      setMedication('');
      setFormulation('');
      setDoseValue('');
      setNote('');
      setShowForm(false);
      await loadContext();
    } catch (err) {
      setFormError(err instanceof Error ? err.message : 'Failed to record treatment event.');
    } finally {
      setSubmitting(false);
    }
  };

  const course = context?.course ?? null;
  const events = context?.events ?? [];

  return (
    <section
      aria-label="GLP-1 Treatment Context"
      className="rounded-2xl border border-slate-200 bg-white p-6 dark:border-[#222838] dark:bg-[#10141F]"
    >
      {/* Clause 9.1 / POR-07 mandatory governance banner */}
      <div
        role="note"
        className="mb-5 flex items-start gap-3 rounded-xl border border-[#2C5CF2]/25 bg-[#F8FAFF] p-4 dark:border-[#7C9CFF]/30 dark:bg-[#0B0F19]"
      >
        <Info className="mt-0.5 h-5 w-5 shrink-0 text-[#2C5CF2] dark:text-[#7C9CFF]" aria-hidden="true" />
        <div>
          <p className="text-sm font-semibold text-[#030616] dark:text-[#EEF1F8]">
            Recorded treatment context — decision support only
          </p>
          <p className="mt-0.5 text-xs text-[#48556A] dark:text-[#A6B0C3]">
            Displays clinician- or partner-recorded medication history for longitudinal context. Zyndio never calculates,
            recommends, or adjusts medication doses (Clause 9.1).
          </p>
        </div>
      </div>

      <div className="flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-2">
          <Activity className="h-5 w-5 text-[#2C5CF2] dark:text-[#7C9CFF]" aria-hidden="true" />
          <h2 className="text-lg font-bold text-[#030616] dark:text-[#EEF1F8]">GLP-1 Treatment Context</h2>
        </div>

        {canEdit && (
          <button
            type="button"
            onClick={() => {
              setFormError(null);
              setShowForm((prev) => !prev);
            }}
            className="inline-flex min-h-[40px] items-center gap-2 rounded-full bg-[#2C5CF2] px-4 text-sm font-semibold text-white hover:bg-[#2449C9] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2] dark:bg-[#7C9CFF] dark:text-[#030616]"
          >
            <Plus className="h-4 w-4" aria-hidden="true" />
            {showForm ? 'Cancel' : 'Record treatment event'}
          </button>
        )}
      </div>

      {loading ? (
        <p className="mt-4 text-sm text-slate-500 dark:text-[#A6B0C3]" role="status">
          Loading treatment context…
        </p>
      ) : loadError ? (
        <p className="mt-4 text-sm text-[#B42318] dark:text-[#FF8F86]" role="alert">
          {loadError}
        </p>
      ) : (
        <>
          {/* Current course summary */}
          {course ? (
            <div className="mt-4 grid grid-cols-1 gap-4 rounded-xl border border-slate-100 bg-slate-50/70 p-4 sm:grid-cols-4 dark:border-[#222838] dark:bg-[#0B0F19]">
              <div>
                <p className="text-xs font-medium text-slate-500 dark:text-[#8F9AAF]">Medication</p>
                <p className="mt-0.5 text-sm font-semibold text-[#030616] dark:text-[#EEF1F8]">
                  {course.medication}
                </p>
                {course.formulation && (
                  <p className="text-xs text-[#48556A] dark:text-[#A6B0C3]">{course.formulation}</p>
                )}
              </div>
              <div>
                <p className="text-xs font-medium text-slate-500 dark:text-[#8F9AAF]">Recorded dose</p>
                <p className="mt-0.5 text-sm font-semibold tabular-nums text-[#030616] dark:text-[#EEF1F8]">
                  {course.currentDoseValue !== null
                    ? `${course.currentDoseValue} ${course.currentDoseUnit ?? ''}`.trim()
                    : 'Not recorded'}
                </p>
              </div>
              <div>
                <p className="text-xs font-medium text-slate-500 dark:text-[#8F9AAF]">Start date</p>
                <p className="mt-0.5 text-sm font-semibold tabular-nums text-[#030616] dark:text-[#EEF1F8]">
                  {course.startDate}
                </p>
              </div>
              <div>
                <p className="text-xs font-medium text-slate-500 dark:text-[#8F9AAF]">Course status</p>
                <span
                  className={`mt-1 inline-flex items-center rounded-md px-2.5 py-0.5 text-xs font-semibold ${statusBadgeClass(
                    course.status
                  )}`}
                >
                  {STATUS_LABELS[course.status]}
                </span>
              </div>
            </div>
          ) : (
            <p className="mt-4 text-sm text-[#48556A] dark:text-[#A6B0C3]">
              No GLP-1 treatment course recorded yet.
            </p>
          )}

          {/* Record treatment event form (physician / care_coordinator only) */}
          {canEdit && showForm && (
            <form
              onSubmit={handleSubmit}
              aria-label="Record treatment event form"
              className="mt-5 space-y-4 rounded-xl border border-slate-200 bg-slate-50/50 p-4 dark:border-[#222838] dark:bg-[#0B0F19]"
            >
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div>
                  <label
                    htmlFor="treatment-event-type"
                    className="block text-xs font-semibold text-[#030616] dark:text-[#EEF1F8]"
                  >
                    Event type
                  </label>
                  <select
                    id="treatment-event-type"
                    value={eventType}
                    onChange={(e) => setEventType(e.target.value as TreatmentEventType)}
                    className="mt-1 w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-[#030616] dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8]"
                  >
                    {(Object.keys(EVENT_TYPE_LABELS) as TreatmentEventType[]).map((t) => (
                      <option key={t} value={t}>
                        {EVENT_TYPE_LABELS[t]}
                      </option>
                    ))}
                  </select>
                </div>

                {(eventType === 'medication_start' || !course) && (
                  <>
                    <div>
                      <label
                        htmlFor="treatment-medication"
                        className="block text-xs font-semibold text-[#030616] dark:text-[#EEF1F8]"
                      >
                        Medication
                      </label>
                      <input
                        id="treatment-medication"
                        type="text"
                        value={medication}
                        onChange={(e) => setMedication(e.target.value)}
                        placeholder="e.g. Semaglutide"
                        maxLength={120}
                        className="mt-1 w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-[#030616] dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8]"
                      />
                    </div>
                    <div>
                      <label
                        htmlFor="treatment-formulation"
                        className="block text-xs font-semibold text-[#030616] dark:text-[#EEF1F8]"
                      >
                        Formulation (optional)
                      </label>
                      <input
                        id="treatment-formulation"
                        type="text"
                        value={formulation}
                        onChange={(e) => setFormulation(e.target.value)}
                        placeholder="e.g. Subcutaneous pen"
                        maxLength={120}
                        className="mt-1 w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-[#030616] dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8]"
                      />
                    </div>
                  </>
                )}

                {(eventType === 'medication_start' || eventType === 'dose_change') && (
                  <>
                    <div>
                      <label
                        htmlFor="treatment-dose-value"
                        className="block text-xs font-semibold text-[#030616] dark:text-[#EEF1F8]"
                      >
                        Recorded dose value
                      </label>
                      <input
                        id="treatment-dose-value"
                        type="number"
                        step="any"
                        min="0.01"
                        value={doseValue}
                        onChange={(e) => setDoseValue(e.target.value)}
                        placeholder="e.g. 0.5"
                        className="mt-1 w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-[#030616] dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8]"
                      />
                    </div>
                    <div>
                      <label
                        htmlFor="treatment-dose-unit"
                        className="block text-xs font-semibold text-[#030616] dark:text-[#EEF1F8]"
                      >
                        Dose unit
                      </label>
                      <input
                        id="treatment-dose-unit"
                        type="text"
                        value={doseUnit}
                        onChange={(e) => setDoseUnit(e.target.value)}
                        placeholder="mg weekly"
                        maxLength={32}
                        className="mt-1 w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-[#030616] dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8]"
                      />
                    </div>
                  </>
                )}

                {(eventType === 'medication_start' || eventType === 'status_change') && (
                  <div>
                    <label
                      htmlFor="treatment-status-value"
                      className="block text-xs font-semibold text-[#030616] dark:text-[#EEF1F8]"
                    >
                      Course status
                    </label>
                    <select
                      id="treatment-status-value"
                      value={statusValue}
                      onChange={(e) => setStatusValue(e.target.value as TreatmentCourseStatus)}
                      className="mt-1 w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-[#030616] dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8]"
                    >
                      {(Object.keys(STATUS_LABELS) as TreatmentCourseStatus[]).map((s) => (
                        <option key={s} value={s}>
                          {STATUS_LABELS[s]}
                        </option>
                      ))}
                    </select>
                  </div>
                )}
              </div>

              <div>
                <label
                  htmlFor="treatment-note"
                  className="block text-xs font-semibold text-[#030616] dark:text-[#EEF1F8]"
                >
                  Tolerability / clinical context note (optional, max 500 chars)
                </label>
                <textarea
                  id="treatment-note"
                  rows={2}
                  maxLength={500}
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                  placeholder="Record patient-reported tolerability or prescribing clinician context…"
                  className="mt-1 w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-[#030616] dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8]"
                />
              </div>

              {formError && (
                <p role="alert" className="text-xs font-semibold text-[#B42318] dark:text-[#FF8F86]">
                  {formError}
                </p>
              )}

              <div className="flex justify-end gap-2">
                <button
                  type="submit"
                  disabled={submitting}
                  className="inline-flex min-h-[40px] items-center rounded-full bg-[#2C5CF2] px-5 text-sm font-semibold text-white hover:bg-[#2449C9] disabled:opacity-50 dark:bg-[#7C9CFF] dark:text-[#030616]"
                >
                  {submitting ? 'Saving…' : 'Save event'}
                </button>
              </div>
            </form>
          )}

          {/* Chronological event history */}
          {events.length > 0 && (
            <div className="mt-5">
              <h3 className="text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-[#8F9AAF]">
                Event History ({events.length})
              </h3>
              <ul className="mt-2 divide-y divide-slate-100 dark:divide-[#222838]">
                {events.map((ev) => (
                  <li key={ev.id} className="flex flex-wrap items-start justify-between gap-2 py-3 text-sm">
                    <div>
                      <span className="font-semibold text-[#030616] dark:text-[#EEF1F8]">
                        {EVENT_TYPE_LABELS[ev.eventType]}
                      </span>
                      {ev.doseValue !== null && (
                        <span className="ml-2 tabular-nums text-[#48556A] dark:text-[#A6B0C3]">
                          · {ev.doseValue} {ev.doseUnit ?? ''}
                        </span>
                      )}
                      {ev.statusValue && (
                        <span className="ml-2 text-xs font-medium text-[#48556A] dark:text-[#A6B0C3]">
                          ({STATUS_LABELS[ev.statusValue]})
                        </span>
                      )}
                      {ev.note && (
                        <p className="mt-1 text-xs text-[#48556A] dark:text-[#A6B0C3]">{ev.note}</p>
                      )}
                    </div>
                    <div className="text-right text-xs text-slate-500 dark:text-[#8F9AAF]">
                      <span className="block tabular-nums">
                        {ev.effectiveAt ? ev.effectiveAt.slice(0, 10) : ''}
                      </span>
                      <span className="uppercase">{ev.source === 'api' ? 'Partner API' : 'Portal'}</span>
                    </div>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </>
      )}
    </section>
  );
};

export default TreatmentContextPanel;
