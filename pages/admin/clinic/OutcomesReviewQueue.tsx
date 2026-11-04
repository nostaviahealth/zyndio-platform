import React, { useCallback, useEffect, useState } from 'react';
import { AlertTriangle, CheckCircle2, Clock, Lock, PauseCircle, RotateCcw, ShieldAlert } from 'lucide-react';
import { supabase } from '../../../lib/supabase';
import { usePortalAuth } from '../../../contexts/PortalAuthContext';
import CriticalBanner from '../../../components/ui/CriticalBanner';
import type { LeanMassFlag, MilestoneKey, OutcomeRecordState } from '../../../lib/outcomesEngine';

export interface OutcomesQueueItem {
  id: string;
  record_id: string;
  org_id: string;
  patient_id: string;
  patient_display_name: string;
  patient_mrn: string;
  milestone: MilestoneKey;
  record_version: number;
  rules_version: string;
  state: OutcomeRecordState;
  lean_mass_flag: LeanMassFlag;
  clinical_context_flag: boolean;
  clinical_flag_cleared_by: string | null;
  clinical_flag_cleared_reason: string | null;
  clinician_summary: string;
  payload: Record<string, unknown>;
  approved_by: string | null;
  approved_at: string | null;
  sent_back_reason: string | null;
  has_partner_disclosure_consent: boolean;
  created_at: string;
  updated_at: string;
}

export interface ReviewOutcomeDecisionInput {
  recordId: string;
  decision: 'approve' | 'hold' | 'send_back';
  clinicianSummary?: string;
  clearClinicalFlag?: boolean;
  note?: string;
}

export interface OutcomesReviewApi {
  listQueue(): Promise<OutcomesQueueItem[]>;
  reviewRecord(input: ReviewOutcomeDecisionInput): Promise<{
    record_id: string;
    state: OutcomeRecordState;
    clinical_context_flag: boolean;
    clinician_summary: string;
  }>;
}

export const supabaseOutcomesReviewApi: OutcomesReviewApi = {
  async listQueue(): Promise<OutcomesQueueItem[]> {
    const { data, error } = await supabase.rpc('list_outcomes_review_queue');
    if (error) throw error;
    return Array.isArray(data) ? (data as OutcomesQueueItem[]) : [];
  },
  async reviewRecord(input: ReviewOutcomeDecisionInput) {
    const { data, error } = await supabase.rpc('review_outcome_record', {
      p_record_id: input.recordId,
      p_decision: input.decision,
      p_clinician_summary: input.clinicianSummary ?? null,
      p_clear_clinical_flag: Boolean(input.clearClinicalFlag),
      p_note: input.note ?? null,
    });
    if (error) throw error;
    return data as {
      record_id: string;
      state: OutcomeRecordState;
      clinical_context_flag: boolean;
      clinician_summary: string;
    };
  },
};

export interface OutcomesReviewQueueProps {
  api?: OutcomesReviewApi;
  role?: string | null;
}

const MILESTONE_LABELS: Record<string, string> = {
  baseline: 'Baseline',
  d90: 'Day 90',
  d180: 'Day 180',
  d365: 'Day 365',
  adhoc: 'Ad-hoc',
};

const STATE_LABELS: Record<OutcomeRecordState, string> = {
  computed: 'Computed',
  in_review: 'In Review',
  approved: 'Approved',
  held: 'On Hold',
  sent_back: 'Sent Back',
  delivered: 'Delivered (Immutable)',
  withdrawn: 'Withdrawn',
};

const OutcomesReviewQueue: React.FC<OutcomesReviewQueueProps> = ({
  api = supabaseOutcomesReviewApi,
  role: roleProp,
}) => {
  const auth = usePortalAuth();
  const role = roleProp ?? auth.role;
  const isPhysician = role === 'physician';

  const [records, setRecords] = useState<OutcomesQueueItem[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [busyRecordId, setBusyRecordId] = useState<string | null>(null);

  // Per-record draft states for editing summary, clearing clinical flag, and adding review notes
  const [draftSummaries, setDraftSummaries] = useState<Record<string, string>>({});
  const [clearFlags, setClearFlags] = useState<Record<string, boolean>>({});
  const [reviewNotes, setReviewNotes] = useState<Record<string, string>>({});

  const load = useCallback(async () => {
    setLoadError(null);
    try {
      const items = await api.listQueue();
      setRecords(items);
      const nextSummaries: Record<string, string> = {};
      for (const item of items) {
        nextSummaries[item.record_id] = item.clinician_summary;
      }
      setDraftSummaries(nextSummaries);
    } catch (err) {
      setLoadError(err instanceof Error ? err.message : 'Unable to load outcomes review queue.');
    }
  }, [api]);

  useEffect(() => {
    load();
  }, [load]);

  const handleDecision = async (rec: OutcomesQueueItem, decision: 'approve' | 'hold' | 'send_back') => {
    setActionError(null);
    const shouldClearFlag = Boolean(clearFlags[rec.record_id]);
    const summaryText = draftSummaries[rec.record_id] ?? rec.clinician_summary;
    const noteText = reviewNotes[rec.record_id] ?? '';

    if (decision === 'approve' && rec.clinical_context_flag && !shouldClearFlag) {
      setActionError('Clinical context flag must be cleared before approving an outcome record.');
      return;
    }

    if (decision === 'approve' && !rec.has_partner_disclosure_consent) {
      setActionError('Partner disclosure consent is required before approving an outcome record.');
      return;
    }

    setBusyRecordId(rec.record_id);
    try {
      const updated = await api.reviewRecord({
        recordId: rec.record_id,
        decision,
        clinicianSummary: summaryText,
        clearClinicalFlag: shouldClearFlag,
        note: noteText,
      });
      setRecords((prev) =>
        (prev ?? []).map((item) =>
          item.record_id === rec.record_id
            ? {
                ...item,
                state: updated.state,
                clinical_context_flag: updated.clinical_context_flag,
                clinician_summary: updated.clinician_summary,
              }
            : item
        )
      );
    } catch (err) {
      setActionError(err instanceof Error ? err.message : 'Failed to submit outcome review decision.');
    } finally {
      setBusyRecordId(null);
    }
  };

  return (
    <div className="relative space-y-6">
      <div>
        <h1 className="text-[28px] font-bold leading-tight text-[#030616] dark:text-[#EEF1F8]">
          Outcomes Review Queue
        </h1>
        <p className="mt-2 text-sm text-[#48556A] dark:text-[#A6B0C3]">
          Review deterministic Schedule C milestone records, clear clinical context flags, and approve partner release.
        </p>
      </div>

      {!isPhysician && (
        <div
          role="note"
          className="rounded-xl border border-slate-200 bg-[#E6ECFA] px-4 py-3 text-sm text-[#030616] dark:border-[#222838] dark:bg-[#10141F] dark:text-[#EEF1F8]"
        >
          View-only access: Only a physician can clear clinical context flags or approve, hold, or send back outcome
          records.
        </div>
      )}

      {actionError && <CriticalBanner>{actionError}</CriticalBanner>}
      {loadError && <CriticalBanner>{loadError}</CriticalBanner>}

      {records === null && !loadError && (
        <p role="status" className="text-sm text-slate-500 dark:text-[#A6B0C3]">
          Loading outcomes review queue…
        </p>
      )}

      {records !== null && records.length === 0 && !loadError && (
        <div className="rounded-2xl border border-slate-200 bg-white p-10 text-center dark:border-[#222838] dark:bg-[#10141F]">
          <p className="text-base font-semibold text-[#030616] dark:text-[#EEF1F8]">
            No outcome records awaiting review
          </p>
          <p className="mt-1 text-sm text-[#48556A] dark:text-[#A6B0C3]">
            Computed milestone records will appear here when baseline and follow-up scans and labs are ready.
          </p>
        </div>
      )}

      {records &&
        records.map((rec) => {
          const isDelivered = rec.state === 'delivered';
          const clearChecked = Boolean(clearFlags[rec.record_id]);
          const flagBlocksApprove = rec.clinical_context_flag && !clearChecked;
          const consentBlocksApprove = !rec.has_partner_disclosure_consent;
          const approveDisabled =
            !isPhysician || isDelivered || busyRecordId === rec.record_id || flagBlocksApprove || consentBlocksApprove;

          return (
            <section
              key={rec.record_id}
              aria-label={`Outcome record ${rec.record_id}`}
              className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm dark:border-[#222838] dark:bg-[#10141F]"
            >
              <div className="flex flex-wrap items-start justify-between gap-4 border-b border-slate-100 pb-4 dark:border-[#222838]">
                <div>
                  <div className="flex flex-wrap items-center gap-2.5">
                    <h2 className="text-lg font-bold text-[#030616] dark:text-[#EEF1F8]">
                      {rec.patient_display_name}
                    </h2>
                    <span className="text-xs font-medium tabular-nums text-slate-500 dark:text-[#8F9AAF]">
                      {rec.patient_mrn}
                    </span>
                    <span className="rounded-full bg-[#DEEAFC] px-3 py-0.5 text-xs font-semibold text-[#2346DD] dark:bg-[#18224A] dark:text-[#AFC3FF]">
                      {MILESTONE_LABELS[rec.milestone] ?? rec.milestone} · v{rec.record_version}
                    </span>
                    <span className="rounded-full border border-slate-300 px-3 py-0.5 text-xs font-semibold text-[#030616] dark:border-[#6C7690] dark:text-[#EEF1F8]">
                      {STATE_LABELS[rec.state] ?? rec.state}
                    </span>
                    {rec.lean_mass_flag !== 'none' && (
                      <span
                        className={`rounded-full px-3 py-0.5 text-xs font-semibold ${
                          rec.lean_mass_flag === 'flagged'
                            ? 'bg-[#FCE8E6] text-[#B42318] dark:bg-[#3A1614] dark:text-[#FF8F86]'
                            : 'bg-[#FBEFD8] text-[#8A4F00] dark:bg-[#2F220D] dark:text-[#F2B65A]'
                        }`}
                      >
                        Lean mass: {rec.lean_mass_flag}
                      </span>
                    )}
                  </div>
                  <p className="mt-1 text-xs tabular-nums text-slate-500 dark:text-[#8F9AAF]">
                    Record ID: {rec.record_id} · Rules {rec.rules_version}
                  </p>
                </div>

                <div className="flex items-center gap-2 text-xs font-semibold">
                  {rec.has_partner_disclosure_consent ? (
                    <span className="inline-flex items-center gap-1 rounded-full bg-[#E3F5EC] px-3 py-1 text-[#15784A] dark:bg-[#0F2A1D] dark:text-[#5FD39A]">
                      <CheckCircle2 className="h-3.5 w-3.5" aria-hidden="true" />
                      Partner disclosure consent granted
                    </span>
                  ) : (
                    <span className="inline-flex items-center gap-1 rounded-full bg-[#FCE8E6] px-3 py-1 text-[#B42318] dark:bg-[#3A1614] dark:text-[#FF8F86]">
                      <ShieldAlert className="h-3.5 w-3.5" aria-hidden="true" />
                      Missing partner disclosure consent
                    </span>
                  )}
                </div>
              </div>

              {rec.clinical_context_flag && (
                <div
                  role="alert"
                  className="mt-4 flex items-start gap-3 rounded-xl border border-[#B42318]/30 bg-[#FCE8E6] p-4 text-sm text-[#B42318] dark:border-[#FF8F86]/30 dark:bg-[#3A1614] dark:text-[#FF8F86]"
                >
                  <AlertTriangle className="mt-0.5 h-5 w-5 shrink-0" aria-hidden="true" />
                  <div className="flex-1">
                    <p className="font-semibold">
                      Clinical Context Flag Active — Flagged records cannot be approved until cleared by a physician.
                    </p>
                    {isPhysician && !isDelivered && (
                      <label className="mt-2 inline-flex cursor-pointer items-center gap-2 font-medium">
                        <input
                          type="checkbox"
                          aria-label={`Clear clinical context flag for ${rec.record_id}`}
                          checked={clearChecked}
                          onChange={(e) =>
                            setClearFlags((prev) => ({
                              ...prev,
                              [rec.record_id]: e.target.checked,
                            }))
                          }
                          className="h-4 w-4 rounded border-slate-400 text-[#2C5CF2] focus:ring-[#2C5CF2]"
                        />
                        I have reviewed the clinical context and clear this flag for partner release
                      </label>
                    )}
                  </div>
                </div>
              )}

              {isDelivered && (
                <div className="mt-4 flex items-center gap-2 rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-xs font-medium text-[#48556A] dark:border-[#222838] dark:bg-[#0B0F19] dark:text-[#A6B0C3]">
                  <Lock className="h-4 w-4 shrink-0" aria-hidden="true" />
                  Delivered records are immutable in place. Any correction must be issued as v{rec.record_version + 1}.
                </div>
              )}

              <div className="mt-4">
                <label
                  htmlFor={`summary-${rec.record_id}`}
                  className="block text-xs font-semibold uppercase tracking-wide text-[#48556A] dark:text-[#A6B0C3]"
                >
                  Deterministic Clinician Summary Narrative (Fixed Template)
                </label>
                <textarea
                  id={`summary-${rec.record_id}`}
                  aria-label={`Clinician summary for ${rec.record_id}`}
                  rows={3}
                  readOnly={!isPhysician || isDelivered}
                  value={draftSummaries[rec.record_id] ?? rec.clinician_summary}
                  onChange={(e) =>
                    setDraftSummaries((prev) => ({
                      ...prev,
                      [rec.record_id]: e.target.value,
                    }))
                  }
                  className="mt-1.5 w-full rounded-xl border border-slate-300 bg-white p-3 text-sm text-[#030616] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2] read-only:bg-slate-50 dark:border-[#6C7690] dark:bg-[#0B0F19] dark:text-[#EEF1F8]"
                />
              </div>

              {isPhysician && !isDelivered && (
                <div className="mt-4 space-y-4">
                  <div>
                    <label
                      htmlFor={`note-${rec.record_id}`}
                      className="block text-xs font-semibold text-[#48556A] dark:text-[#A6B0C3]"
                    >
                      Physician Review Note / Flag Clearance Reason
                    </label>
                    <input
                      id={`note-${rec.record_id}`}
                      type="text"
                      aria-label={`Review note for ${rec.record_id}`}
                      placeholder="Document flag clearance reason, hold note, or send-back instructions…"
                      value={reviewNotes[rec.record_id] ?? ''}
                      onChange={(e) =>
                        setReviewNotes((prev) => ({
                          ...prev,
                          [rec.record_id]: e.target.value,
                        }))
                      }
                      className="mt-1 min-h-[44px] w-full rounded-xl border border-slate-300 bg-white px-3.5 text-sm text-[#030616] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2] dark:border-[#6C7690] dark:bg-[#0B0F19] dark:text-[#EEF1F8]"
                    />
                  </div>

                  <div className="flex flex-wrap items-center gap-3">
                    <button
                      type="button"
                      aria-label={`Approve ${rec.record_id}`}
                      disabled={approveDisabled}
                      onClick={() => handleDecision(rec, 'approve')}
                      className="inline-flex min-h-[44px] items-center gap-2 rounded-full bg-[#2C5CF2] px-5 text-sm font-semibold text-white hover:bg-[#2450D8] disabled:cursor-not-allowed disabled:opacity-40 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2]"
                    >
                      <CheckCircle2 className="h-4 w-4" aria-hidden="true" />
                      Approve &amp; Release
                    </button>

                    <button
                      type="button"
                      aria-label={`Hold ${rec.record_id}`}
                      disabled={busyRecordId === rec.record_id}
                      onClick={() => handleDecision(rec, 'hold')}
                      className="inline-flex min-h-[44px] items-center gap-2 rounded-full border border-slate-300 bg-white px-5 text-sm font-semibold text-[#030616] hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-40 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2] dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8]"
                    >
                      <PauseCircle className="h-4 w-4" aria-hidden="true" />
                      Hold
                    </button>

                    <button
                      type="button"
                      aria-label={`Send back ${rec.record_id}`}
                      disabled={busyRecordId === rec.record_id}
                      onClick={() => handleDecision(rec, 'send_back')}
                      className="inline-flex min-h-[44px] items-center gap-2 rounded-full border border-slate-300 bg-white px-5 text-sm font-semibold text-[#B42318] hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-40 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2] dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#FF8F86]"
                    >
                      <RotateCcw className="h-4 w-4" aria-hidden="true" />
                      Send Back
                    </button>

                    {flagBlocksApprove && (
                      <span className="inline-flex items-center gap-1 text-xs font-medium text-[#8A4F00] dark:text-[#F2B65A]">
                        <Clock className="h-3.5 w-3.5" aria-hidden="true" />
                        Clear clinical context flag to enable approval
                      </span>
                    )}
                  </div>
                </div>
              )}
            </section>
          );
        })}
    </div>
  );
};

export default OutcomesReviewQueue;
