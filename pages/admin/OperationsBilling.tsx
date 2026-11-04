import React, { useCallback, useEffect, useState } from 'react';
import PageHeader from '../../components/ui/PageHeader';
import Button from '../../components/admin-auth/Button';
import TextInput from '../../components/ui/TextInput';
import SelectField from '../../components/ui/SelectField';
import { useToast } from '../../components/ui/Toast';
import { FOCUS_RING_CLASS } from '../../components/ui/focusRing';
import {
  IncidentSeverity,
  MonthlyUsageSummary,
  OrgTerminationExport,
  PatientDeletionConfirmation,
  PatientLegalHold,
  SecurityIncident,
  confirmPatientDataDeletion,
  getOrgMonthlyUsageSummary,
  listOrgTerminationExports,
  listPatientDeletionConfirmations,
  listPatientLegalHolds,
  listSecurityIncidents,
  reportSecurityIncident,
  requestOrgTerminationExport,
  setPatientLegalHold,
} from '../../lib/opsBillingApi';

function currentUtcMonthStart(): string {
  const now = new Date();
  const year = now.getUTCFullYear();
  const month = String(now.getUTCMonth() + 1).padStart(2, '0');
  return `${year}-${month}-01`;
}

function formatUsdFromCents(cents: number): string {
  return `$${(cents / 100).toFixed(2)}`;
}

function formatDateTime(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toISOString().replace('T', ' ').slice(0, 16) + ' UTC';
}

const OperationsBilling: React.FC = () => {
  const { showToast } = useToast();

  // PP-02 state
  const [selectedMonth, setSelectedMonth] = useState<string>(currentUtcMonthStart);
  const [usage, setUsage] = useState<MonthlyUsageSummary | null>(null);
  const [loadingData, setLoadingData] = useState<boolean>(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  // OPS-01 state
  const [exportsList, setExportsList] = useState<OrgTerminationExport[]>([]);
  const [exportBusy, setExportBusy] = useState<boolean>(false);

  // OPS-02 state
  const [legalHolds, setLegalHolds] = useState<PatientLegalHold[]>([]);
  const [deletionCerts, setDeletionCerts] = useState<PatientDeletionConfirmation[]>([]);
  const [targetPatientId, setTargetPatientId] = useState<string>('');
  const [holdReason, setHoldReason] = useState<string>('');
  const [holdBusy, setHoldBusy] = useState<boolean>(false);
  const [deleteBusy, setDeleteBusy] = useState<boolean>(false);
  const [ops02Error, setOps02Error] = useState<string | null>(null);

  // OPS-03 state
  const [incidents, setIncidents] = useState<SecurityIncident[]>([]);
  const [incidentSeverity, setIncidentSeverity] = useState<IncidentSeverity>('P1');
  const [incidentTitle, setIncidentTitle] = useState<string>('');
  const [incidentSummary, setIncidentSummary] = useState<string>('');
  const [notifyNow, setNotifyNow] = useState<boolean>(true);
  const [incidentBusy, setIncidentBusy] = useState<boolean>(false);
  const [ops03Error, setOps03Error] = useState<string | null>(null);

  const loadAll = useCallback(async (month: string) => {
    setLoadingData(true);
    setLoadError(null);
    try {
      const [usageRes, exportsRes, holdsRes, certsRes, incidentsRes] = await Promise.all([
        getOrgMonthlyUsageSummary(month),
        listOrgTerminationExports(),
        listPatientLegalHolds(),
        listPatientDeletionConfirmations(),
        listSecurityIncidents(),
      ]);
      setUsage(usageRes);
      setExportsList(exportsRes);
      setLegalHolds(holdsRes);
      setDeletionCerts(certsRes);
      setIncidents(incidentsRes);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unable to load operations and billing data.';
      setLoadError(message);
    } finally {
      setLoadingData(false);
    }
  }, []);

  useEffect(() => {
    void loadAll(selectedMonth);
  }, [loadAll, selectedMonth]);

  const handleGenerateExport = async () => {
    setExportBusy(true);
    try {
      const created = await requestOrgTerminationExport();
      setExportsList((prev) => [created, ...prev]);
      showToast({ message: 'Clause 6.6 termination data export manifest generated.' });
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Failed to generate termination export.';
      showToast({ message: msg });
    } finally {
      setExportBusy(false);
    }
  };

  const handlePlaceLegalHold = async (hold: boolean) => {
    setOps02Error(null);
    const trimmedId = targetPatientId.trim();
    if (!trimmedId) {
      setOps02Error('Patient ID is required.');
      return;
    }
    if (hold && holdReason.trim().length < 3) {
      setOps02Error('Legal hold reason must be at least 3 characters.');
      return;
    }
    setHoldBusy(true);
    try {
      await setPatientLegalHold(trimmedId, hold, holdReason);
      const updatedHolds = await listPatientLegalHolds();
      setLegalHolds(updatedHolds);
      showToast({
        message: hold ? 'Legal hold placed on patient record.' : 'Legal hold released.',
      });
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Failed to update legal hold.';
      setOps02Error(msg);
    } finally {
      setHoldBusy(false);
    }
  };

  const handleConfirmDeletion = async () => {
    setOps02Error(null);
    const trimmedId = targetPatientId.trim();
    if (!trimmedId) {
      setOps02Error('Patient ID is required to confirm deletion.');
      return;
    }
    setDeleteBusy(true);
    try {
      const cert = await confirmPatientDataDeletion(trimmedId);
      setDeletionCerts((prev) => [cert, ...prev]);
      showToast({
        message: `Patient clinical data deleted. Certificate ${cert.confirmation_code} issued.`,
      });
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Patient deletion refused.';
      if (msg.includes('patient_under_legal_hold')) {
        setOps02Error('Deletion refused: patient record is under an active legal hold (patient_under_legal_hold).');
      } else {
        setOps02Error(msg);
      }
    } finally {
      setDeleteBusy(false);
    }
  };

  const handleReportIncident = async (e: React.FormEvent) => {
    e.preventDefault();
    setOps03Error(null);
    if (incidentTitle.trim().length < 3) {
      setOps03Error('Incident title must be between 3 and 200 characters.');
      return;
    }
    if (incidentSummary.trim().length < 10) {
      setOps03Error('Incident summary must be between 10 and 2,000 characters.');
      return;
    }
    setIncidentBusy(true);
    try {
      const created = await reportSecurityIncident(
        incidentSeverity,
        incidentTitle,
        incidentSummary,
        notifyNow
      );
      setIncidents((prev) => [created, ...prev]);
      setIncidentTitle('');
      setIncidentSummary('');
      showToast({
        message: notifyNow
          ? 'Security incident logged and 72-hour notification queued.'
          : 'Security incident logged with 72-hour notification deadline.',
      });
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Failed to report security incident.';
      setOps03Error(msg);
    } finally {
      setIncidentBusy(false);
    }
  };

  return (
    <div className="space-y-8">
      <PageHeader
        title="Operations and billing"
        description="Active patient monthly metering (Schedule B), Clause 6.6 termination exports, legal holds and deletion certificates, and Clause 8.8 72-hour security incident notifications."
      />

      {loadError && (
        <div
          role="alert"
          className="rounded-[12px] border border-[#B42318] bg-[#FEF3F2] p-4 text-sm text-[#B42318] dark:border-[#FF8F86] dark:bg-[#2C1215] dark:text-[#FF8F86]"
        >
          {loadError}
        </div>
      )}

      {/* ===================================================================
          1. PP-02: Active Patients Monthly Metering & Schedule B Overage
      =================================================================== */}
      <section
        aria-labelledby="pp02-heading"
        className="rounded-[14px] border border-slate-200 bg-white p-6 dark:border-[#222838] dark:bg-[#10141F]"
      >
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div>
            <h2 id="pp02-heading" className="text-lg font-bold text-[#030616] dark:text-[#EEF1F8]">
              Active patients metering (Schedule B)
            </h2>
            <p className="mt-1 text-sm text-[#48556A] dark:text-[#A6B0C3]">
              Deduplicated per organization, UTC calendar month, and patient across sign-in and data-processed events.
            </p>
          </div>
          <div className="flex items-center gap-2">
            <label
              htmlFor="billing-month-input"
              className="text-sm font-medium text-[#030616] dark:text-[#EEF1F8]"
            >
              Billing month (UTC)
            </label>
            <TextInput
              id="billing-month-input"
              type="date"
              value={selectedMonth}
              onChange={(e) => setSelectedMonth(e.target.value)}
              className="w-44"
            />
          </div>
        </div>

        {loadingData && !usage ? (
          <p className="mt-4 text-sm text-[#48556A] dark:text-[#A6B0C3]">Loading monthly usage summary…</p>
        ) : usage ? (
          <div className="mt-6 space-y-6">
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
              <div className="rounded-[10px] border border-slate-200 bg-[#F8FAFC] p-4 dark:border-[#222838] dark:bg-[#0B0F19]">
                <p className="text-xs font-medium uppercase tracking-wide text-[#48556A] dark:text-[#A6B0C3]">
                  Active patients total
                </p>
                <p
                  data-testid="active-patients-total"
                  className="mt-2 text-2xl font-bold text-[#030616] dark:text-[#EEF1F8]"
                >
                  {usage.active_patients_total.toLocaleString()}
                </p>
                <p className="mt-1 text-xs text-[#48556A] dark:text-[#A6B0C3]">
                  {usage.sign_in_count.toLocaleString()} sign-in · {usage.data_processed_count.toLocaleString()} data processed
                </p>
              </div>

              <div className="rounded-[10px] border border-slate-200 bg-[#F8FAFC] p-4 dark:border-[#222838] dark:bg-[#0B0F19]">
                <p className="text-xs font-medium uppercase tracking-wide text-[#48556A] dark:text-[#A6B0C3]">
                  Included in base plan
                </p>
                <p className="mt-2 text-2xl font-bold text-[#030616] dark:text-[#EEF1F8]">
                  {usage.included_patients.toLocaleString()}
                </p>
                <p className="mt-1 text-xs text-[#48556A] dark:text-[#A6B0C3]">
                  Patients 1–1,000 included
                </p>
              </div>

              <div className="rounded-[10px] border border-slate-200 bg-[#F8FAFC] p-4 dark:border-[#222838] dark:bg-[#0B0F19]">
                <p className="text-xs font-medium uppercase tracking-wide text-[#48556A] dark:text-[#A6B0C3]">
                  Billable overage patients
                </p>
                <p
                  data-testid="billable-overage-patients"
                  className="mt-2 text-2xl font-bold text-[#030616] dark:text-[#EEF1F8]"
                >
                  {usage.billable_overage_patients.toLocaleString()}
                </p>
                <p className="mt-1 text-xs text-[#48556A] dark:text-[#A6B0C3]">
                  Active patients above 1,000
                </p>
              </div>

              <div className="rounded-[10px] border border-slate-200 bg-[#F8FAFC] p-4 dark:border-[#222838] dark:bg-[#0B0F19]">
                <p className="text-xs font-medium uppercase tracking-wide text-[#48556A] dark:text-[#A6B0C3]">
                  Estimated overage fee
                </p>
                <p
                  data-testid="overage-fee-usd"
                  className="mt-2 text-2xl font-bold text-[#030616] dark:text-[#EEF1F8]"
                >
                  {formatUsdFromCents(usage.overage_fee_cents)}
                </p>
                <p className="mt-1 text-xs text-[#48556A] dark:text-[#A6B0C3]">
                  Schedule B tiered rate
                </p>
              </div>
            </div>

            <div className="overflow-x-auto">
              <table
                aria-label="Schedule B overage tiers"
                className="w-full border-collapse text-left text-sm"
              >
                <thead>
                  <tr className="border-b border-slate-200 text-xs font-semibold uppercase tracking-wide text-[#48556A] dark:border-[#222838] dark:text-[#A6B0C3]">
                    <th className="py-2 pr-4">Schedule B tier</th>
                    <th className="py-2 pr-4">Rate per patient</th>
                    <th className="py-2 pr-4">Patients in tier</th>
                    <th className="py-2">Tier subtotal</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-200 text-[#030616] dark:divide-[#222838] dark:text-[#EEF1F8]">
                  <tr>
                    <td className="py-2.5 pr-4 font-medium">1 – 1,000 active patients</td>
                    <td className="py-2.5 pr-4">Included ($0.00)</td>
                    <td className="py-2.5 pr-4">
                      {Math.min(usage.active_patients_total, usage.included_patients).toLocaleString()}
                    </td>
                    <td className="py-2.5">$0.00</td>
                  </tr>
                  <tr>
                    <td className="py-2.5 pr-4 font-medium">1,001 – 2,500 active patients</td>
                    <td className="py-2.5 pr-4">$0.50 / month</td>
                    <td className="py-2.5 pr-4">
                      {usage.tiers.tier_1001_2500_patients.toLocaleString()}
                    </td>
                    <td className="py-2.5">
                      {formatUsdFromCents(usage.tiers.tier_1001_2500_cents)}
                    </td>
                  </tr>
                  <tr>
                    <td className="py-2.5 pr-4 font-medium">2,501 – 10,000 active patients</td>
                    <td className="py-2.5 pr-4">$0.35 / month</td>
                    <td className="py-2.5 pr-4">
                      {usage.tiers.tier_2501_10000_patients.toLocaleString()}
                    </td>
                    <td className="py-2.5">
                      {formatUsdFromCents(usage.tiers.tier_2501_10000_cents)}
                    </td>
                  </tr>
                  <tr>
                    <td className="py-2.5 pr-4 font-medium">10,001+ active patients</td>
                    <td className="py-2.5 pr-4">$0.25 / month</td>
                    <td className="py-2.5 pr-4">
                      {usage.tiers.tier_10001_plus_patients.toLocaleString()}
                    </td>
                    <td className="py-2.5">
                      {formatUsdFromCents(usage.tiers.tier_10001_plus_cents)}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        ) : null}
      </section>

      {/* ===================================================================
          2. OPS-01: Clause 6.6 Patient Data Export (30-Day SLA & 60-Day Read-Only)
      =================================================================== */}
      <section
        aria-labelledby="ops01-heading"
        className="rounded-[14px] border border-slate-200 bg-white p-6 dark:border-[#222838] dark:bg-[#10141F]"
      >
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div>
            <h2 id="ops01-heading" className="text-lg font-bold text-[#030616] dark:text-[#EEF1F8]">
              Patient data export on termination (Clause 6.6)
            </h2>
            <p className="mt-1 text-sm text-[#48556A] dark:text-[#A6B0C3]">
              Generates a machine-readable JSON manifest and document bundle within the 30-day export SLA and records the 60-day read-only window.
            </p>
          </div>
          <Button
            type="button"
            variant="primary"
            busy={exportBusy}
            busyLabel="Generating export…"
            onClick={handleGenerateExport}
          >
            Generate termination export
          </Button>
        </div>

        {exportsList.length === 0 ? (
          <p className="mt-4 text-sm text-[#48556A] dark:text-[#A6B0C3]">
            No termination data exports requested yet.
          </p>
        ) : (
          <div className="mt-4 space-y-4">
            {exportsList.map((exp) => (
              <div
                key={exp.id}
                data-testid="termination-export-card"
                className="rounded-[10px] border border-slate-200 bg-[#F8FAFC] p-4 dark:border-[#222838] dark:bg-[#0B0F19]"
              >
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <span className="text-sm font-semibold text-[#030616] dark:text-[#EEF1F8]">
                    Export {exp.id} · Schema v{exp.manifest.schema_version}
                  </span>
                  <span className="rounded-full bg-[#E8EDFD] px-2.5 py-0.5 text-xs font-semibold text-[#2C5CF2] dark:bg-[#18224A] dark:text-[#AFC3FF]">
                    {exp.status}
                  </span>
                </div>
                <dl className="mt-3 grid grid-cols-1 gap-2 text-xs text-[#48556A] dark:text-[#A6B0C3] sm:grid-cols-3">
                  <div>
                    <dt className="font-medium text-[#030616] dark:text-[#EEF1F8]">Records included</dt>
                    <dd>
                      {exp.manifest.patient_count} patients · {exp.manifest.lab_report_count} lab reports
                    </dd>
                  </div>
                  <div>
                    <dt className="font-medium text-[#030616] dark:text-[#EEF1F8]">30-day delivery due</dt>
                    <dd>{formatDateTime(exp.due_at)}</dd>
                  </div>
                  <div>
                    <dt className="font-medium text-[#030616] dark:text-[#EEF1F8]">60-day read-only until</dt>
                    <dd>{formatDateTime(exp.readonly_until)}</dd>
                  </div>
                </dl>
                <p className="mt-2 break-all font-mono text-xs text-[#48556A] dark:text-[#A6B0C3]">
                  SHA-256: {exp.manifest.sha256_manifest}
                </p>
              </div>
            ))}
          </div>
        )}
      </section>

      {/* ===================================================================
          3. OPS-02: Legal Holds & Written Deletion Confirmation
      =================================================================== */}
      <section
        aria-labelledby="ops02-heading"
        className="rounded-[14px] border border-slate-200 bg-white p-6 dark:border-[#222838] dark:bg-[#10141F]"
      >
        <h2 id="ops02-heading" className="text-lg font-bold text-[#030616] dark:text-[#EEF1F8]">
          Patient legal holds and written deletion confirmation
        </h2>
        <p className="mt-1 text-sm text-[#48556A] dark:text-[#A6B0C3]">
          Place or release legal holds to block deletion, or execute clinical data deletion and issue a SHA-256 written confirmation certificate.
        </p>

        {ops02Error && (
          <div
            role="alert"
            className="mt-4 rounded-[10px] border border-[#B42318] bg-[#FEF3F2] p-3 text-sm text-[#B42318] dark:border-[#FF8F86] dark:bg-[#2C1215] dark:text-[#FF8F86]"
          >
            {ops02Error}
          </div>
        )}

        <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div>
            <label
              htmlFor="ops02-patient-id"
              className="mb-1.5 block text-sm font-medium text-[#030616] dark:text-[#EEF1F8]"
            >
              Patient UUID
            </label>
            <TextInput
              id="ops02-patient-id"
              placeholder="00000000-0000-0000-0000-0000000a1001"
              value={targetPatientId}
              onChange={(e) => setTargetPatientId(e.target.value)}
            />
          </div>
          <div>
            <label
              htmlFor="ops02-hold-reason"
              className="mb-1.5 block text-sm font-medium text-[#030616] dark:text-[#EEF1F8]"
            >
              Legal hold reason (required to place hold)
            </label>
            <TextInput
              id="ops02-hold-reason"
              placeholder="Litigation preservation order #2026-11"
              value={holdReason}
              onChange={(e) => setHoldReason(e.target.value)}
            />
          </div>
        </div>

        <div className="mt-4 flex flex-wrap items-center gap-3">
          <Button
            type="button"
            variant="outline"
            busy={holdBusy}
            onClick={() => handlePlaceLegalHold(true)}
          >
            Place legal hold
          </Button>
          <Button
            type="button"
            variant="outline"
            busy={holdBusy}
            onClick={() => handlePlaceLegalHold(false)}
          >
            Release legal hold
          </Button>
          <Button
            type="button"
            variant="destructive"
            busy={deleteBusy}
            busyLabel="Deleting patient data…"
            onClick={handleConfirmDeletion}
          >
            Delete patient data and issue certificate
          </Button>
        </div>

        <div className="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-2">
          <div>
            <h3 className="text-sm font-semibold text-[#030616] dark:text-[#EEF1F8]">
              Active legal holds ({legalHolds.length})
            </h3>
            {legalHolds.length === 0 ? (
              <p className="mt-2 text-xs text-[#48556A] dark:text-[#A6B0C3]">
                No active legal holds in this organization.
              </p>
            ) : (
              <ul className="mt-2 space-y-2">
                {legalHolds.map((h) => (
                  <li
                    key={h.patient_id}
                    className="rounded-[10px] border border-slate-200 bg-[#F8FAFC] p-3 text-xs dark:border-[#222838] dark:bg-[#0B0F19]"
                  >
                    <p className="font-mono font-semibold text-[#030616] dark:text-[#EEF1F8]">
                      Patient: {h.patient_id}
                    </p>
                    <p className="mt-1 text-[#48556A] dark:text-[#A6B0C3]">Reason: {h.reason}</p>
                  </li>
                ))}
              </ul>
            )}
          </div>

          <div>
            <h3 className="text-sm font-semibold text-[#030616] dark:text-[#EEF1F8]">
              Written deletion confirmation certificates ({deletionCerts.length})
            </h3>
            {deletionCerts.length === 0 ? (
              <p className="mt-2 text-xs text-[#48556A] dark:text-[#A6B0C3]">
                No deletion confirmation certificates issued yet.
              </p>
            ) : (
              <ul className="mt-2 space-y-2">
                {deletionCerts.map((cert) => (
                  <li
                    key={cert.id}
                    data-testid="deletion-certificate-card"
                    className="rounded-[10px] border border-slate-200 bg-[#F8FAFC] p-3 text-xs dark:border-[#222838] dark:bg-[#0B0F19]"
                  >
                    <div className="flex items-center justify-between gap-2">
                      <span className="font-mono font-bold text-[#030616] dark:text-[#EEF1F8]">
                        {cert.confirmation_code}
                      </span>
                      <span className="font-mono text-[#48556A] dark:text-[#A6B0C3]">
                        Ref: {cert.patient_ref}
                      </span>
                    </div>
                    <p className="mt-1 text-[#48556A] dark:text-[#A6B0C3]">
                      Deleted: {cert.summary.deleted_lab_reports} lab reports · {cert.summary.deleted_profiles} profiles · {cert.summary.deleted_consents} consents
                    </p>
                    <p className="mt-1 break-all font-mono text-[11px] text-[#48556A] dark:text-[#A6B0C3]">
                      SHA-256: {cert.certificate_sha256}
                    </p>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>
      </section>

      {/* ===================================================================
          4. OPS-03: Clause 8.8 72-Hour Security Incident Notification Console
      =================================================================== */}
      <section
        aria-labelledby="ops03-heading"
        className="rounded-[14px] border border-slate-200 bg-white p-6 dark:border-[#222838] dark:bg-[#10141F]"
      >
        <h2 id="ops03-heading" className="text-lg font-bold text-[#030616] dark:text-[#EEF1F8]">
          72-hour security incident notification (Clause 8.8)
        </h2>
        <p className="mt-1 text-sm text-[#48556A] dark:text-[#A6B0C3]">
          Record confirmed security incidents, compute the mandatory 72-hour notification deadline, and dispatch customer notices via the notification outbox.
        </p>

        {ops03Error && (
          <div
            role="alert"
            className="mt-4 rounded-[10px] border border-[#B42318] bg-[#FEF3F2] p-3 text-sm text-[#B42318] dark:border-[#FF8F86] dark:bg-[#2C1215] dark:text-[#FF8F86]"
          >
            {ops03Error}
          </div>
        )}

        <form onSubmit={handleReportIncident} className="mt-4 space-y-4">
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
            <div>
              <label
                htmlFor="ops03-severity"
                className="mb-1.5 block text-sm font-medium text-[#030616] dark:text-[#EEF1F8]"
              >
                Severity
              </label>
              <SelectField
                id="ops03-severity"
                wrapperClassName="w-full"
                value={incidentSeverity}
                onChange={(e) => setIncidentSeverity(e.target.value as IncidentSeverity)}
              >
                <option value="P1">P1 — Critical</option>
                <option value="P2">P2 — High</option>
                <option value="P3">P3 — Moderate</option>
              </SelectField>
            </div>
            <div className="sm:col-span-2">
              <label
                htmlFor="ops03-title"
                className="mb-1.5 block text-sm font-medium text-[#030616] dark:text-[#EEF1F8]"
              >
                Incident title
              </label>
              <TextInput
                id="ops03-title"
                placeholder="Confirmed credential stuffing spike on portal endpoint"
                value={incidentTitle}
                onChange={(e) => setIncidentTitle(e.target.value)}
              />
            </div>
          </div>

          <div>
            <label
              htmlFor="ops03-summary"
              className="mb-1.5 block text-sm font-medium text-[#030616] dark:text-[#EEF1F8]"
            >
              Incident summary (no PHI)
            </label>
            <textarea
              id="ops03-summary"
              rows={3}
              placeholder="Describe the scope, mitigation actions, and confirmation timestamp (no patient PHI)."
              value={incidentSummary}
              onChange={(e) => setIncidentSummary(e.target.value)}
              className={`w-full rounded-md border border-slate-300 bg-white p-3 text-sm text-[#030616] dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8] ${FOCUS_RING_CLASS}`}
            />
          </div>

          <div className="flex flex-wrap items-center justify-between gap-4">
            <label className="flex items-center gap-2 text-sm text-[#030616] dark:text-[#EEF1F8]">
              <input
                type="checkbox"
                checked={notifyNow}
                onChange={(e) => setNotifyNow(e.target.checked)}
                className="h-4 w-4 rounded border-slate-300"
              />
              Enqueue 72-hour customer notification immediately
            </label>
            <Button
              type="submit"
              variant="primary"
              busy={incidentBusy}
              busyLabel="Reporting incident…"
            >
              Report security incident
            </Button>
          </div>
        </form>

        {incidents.length > 0 && (
          <div className="mt-6 space-y-3">
            <h3 className="text-sm font-semibold text-[#030616] dark:text-[#EEF1F8]">
              Logged security incidents ({incidents.length})
            </h3>
            {incidents.map((inc) => (
              <div
                key={inc.id}
                data-testid="security-incident-card"
                className="rounded-[10px] border border-slate-200 bg-[#F8FAFC] p-4 text-xs dark:border-[#222838] dark:bg-[#0B0F19]"
              >
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <span className="text-sm font-bold text-[#030616] dark:text-[#EEF1F8]">
                    [{inc.severity}] {inc.title}
                  </span>
                  <span className="rounded-full bg-[#E8EDFD] px-2.5 py-0.5 text-xs font-semibold text-[#2C5CF2] dark:bg-[#18224A] dark:text-[#AFC3FF]">
                    {inc.status}
                  </span>
                </div>
                <p className="mt-1.5 text-[#48556A] dark:text-[#A6B0C3]">{inc.summary}</p>
                <div className="mt-2 flex flex-wrap gap-4 text-[#48556A] dark:text-[#A6B0C3]">
                  <span>Confirmed: {formatDateTime(inc.confirmed_at)}</span>
                  <span>72h Deadline: {formatDateTime(inc.notify_deadline_at)}</span>
                  <span>Notified: {formatDateTime(inc.notified_at)}</span>
                </div>
              </div>
            ))}
          </div>
        )}
      </section>
    </div>
  );
};

export default OperationsBilling;
