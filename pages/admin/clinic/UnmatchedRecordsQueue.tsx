import React, { useCallback, useEffect, useState } from 'react';
import { Link2, ScanLine, CheckCircle2 } from 'lucide-react';
import { supabase } from '../../../lib/supabase';
import { usePortalAuth } from '../../../contexts/PortalAuthContext';
import CriticalBanner from '../../../components/ui/CriticalBanner';

export interface UnmatchedPartnerScanItem {
  id: string;
  org_id: string;
  patient_id: string | null;
  zyndio_patient_id: string | null;
  partner_patient_id: string;
  partner_scan_id: string;
  partner_scan_version: number;
  scan_date: string;
  site_id: string | null;
  device_vendor: string;
  device_model: string;
  software_version: string;
  measures: {
    weight_lb?: number | null;
    fat_mass_lb?: number | null;
    lean_mass_lb?: number | null;
    visceral_fat?: number | null;
    [key: string]: unknown;
  };
  binding_status: 'bound' | 'unmatched' | 'rejected';
  created_at: string;
}

export interface ClinicPatientOption {
  patientId: string;
  displayName: string;
  mrn: string;
}

export interface UnmatchedRecordsApi {
  listUnmatchedScans(): Promise<UnmatchedPartnerScanItem[]>;
  listClinicPatients(): Promise<ClinicPatientOption[]>;
  bindScan(scanId: string, patientId: string): Promise<{
    scan_id: string;
    patient_id: string;
    binding_status: 'bound';
  }>;
}

export const supabaseUnmatchedRecordsApi: UnmatchedRecordsApi = {
  async listUnmatchedScans(): Promise<UnmatchedPartnerScanItem[]> {
    const { data, error } = await supabase.rpc('list_unmatched_partner_scans');
    if (error) throw error;
    return Array.isArray(data) ? (data as UnmatchedPartnerScanItem[]) : [];
  },
  async listClinicPatients(): Promise<ClinicPatientOption[]> {
    const { data, error } = await supabase.rpc('physician_patient_roster', {
      p_search: null,
      p_filter: 'all',
      p_sort: 'name',
      p_limit: 100,
      p_offset: 0,
    });
    if (error) throw error;
    const rows = Array.isArray(data) ? (data as Array<Record<string, unknown>>) : [];
    return rows.map((r) => ({
      patientId: String(r.patient_id),
      displayName: String(r.display_name ?? ''),
      mrn: String(r.mrn ?? ''),
    }));
  },
  async bindScan(scanId: string, patientId: string) {
    const { data, error } = await supabase.rpc('bind_unmatched_partner_scan', {
      p_scan_id: scanId,
      p_patient_id: patientId,
    });
    if (error) throw error;
    return data as {
      scan_id: string;
      patient_id: string;
      binding_status: 'bound';
    };
  },
};

export interface UnmatchedRecordsQueueProps {
  api?: UnmatchedRecordsApi;
  role?: string | null;
}

const UnmatchedRecordsQueue: React.FC<UnmatchedRecordsQueueProps> = ({
  api = supabaseUnmatchedRecordsApi,
  role: roleProp,
}) => {
  const auth = usePortalAuth();
  const role = roleProp ?? auth.role;
  const canBind = role === 'physician' || role === 'care_coordinator';

  const [scans, setScans] = useState<UnmatchedPartnerScanItem[] | null>(null);
  const [patients, setPatients] = useState<ClinicPatientOption[]>([]);
  const [selectedPatientByScan, setSelectedPatientByScan] = useState<Record<string, string>>({});
  const [busyScanId, setBusyScanId] = useState<string | null>(null);
  const [boundNotice, setBoundNotice] = useState<string | null>(null);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const load = useCallback(async () => {
    setErrorMsg(null);
    try {
      const [scanRows, patientRows] = await Promise.all([
        api.listUnmatchedScans(),
        api.listClinicPatients(),
      ]);
      setScans(scanRows);
      setPatients(patientRows);
      if (patientRows.length > 0) {
        const defaults: Record<string, string> = {};
        for (const s of scanRows) {
          defaults[s.id] = patientRows[0].patientId;
        }
        setSelectedPatientByScan(defaults);
      }
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Unable to load unmatched partner scans.');
    }
  }, [api]);

  useEffect(() => {
    load();
  }, [load]);

  const handleBind = async (scan: UnmatchedPartnerScanItem) => {
    const patientId = selectedPatientByScan[scan.id];
    if (!patientId) {
      setErrorMsg('Please select a clinic patient to bind this scan.');
      return;
    }

    setErrorMsg(null);
    setBoundNotice(null);
    setBusyScanId(scan.id);
    try {
      await api.bindScan(scan.id, patientId);
      const matchedPatient = patients.find((p) => p.patientId === patientId);
      setScans((prev) => (prev ?? []).filter((s) => s.id !== scan.id));
      setBoundNotice(
        `Scan ${scan.partner_scan_id} bound to ${matchedPatient?.displayName ?? patientId} (${matchedPatient?.mrn ?? ''}).`
      );
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Failed to bind partner scan.');
    } finally {
      setBusyScanId(null);
    }
  };

  return (
    <div className="relative space-y-6">
      <div>
        <h1 className="text-[28px] font-bold leading-tight text-[#030616] dark:text-[#EEF1F8]">
          Unmatched Partner Scans Queue
        </h1>
        <p className="mt-2 text-sm text-[#48556A] dark:text-[#A6B0C3]">
          Resolve DEXASCAN body composition scans that arrived with an unknown or missing Zyndio patient ID.
        </p>
      </div>

      {errorMsg && <CriticalBanner>{errorMsg}</CriticalBanner>}

      {boundNotice && (
        <div
          role="status"
          className="flex items-center gap-2 rounded-xl border border-[#15784A]/30 bg-[#E3F5EC] px-4 py-3 text-sm font-medium text-[#15784A] dark:bg-[#0F2A1D] dark:text-[#5FD39A]"
        >
          <CheckCircle2 className="h-4 w-4 shrink-0" aria-hidden="true" />
          {boundNotice}
        </div>
      )}

      {scans === null && !errorMsg && (
        <p role="status" className="text-sm text-slate-500 dark:text-[#A6B0C3]">
          Loading unmatched partner scans…
        </p>
      )}

      {scans !== null && scans.length === 0 && !errorMsg && (
        <div className="rounded-2xl border border-slate-200 bg-white p-10 text-center dark:border-[#222838] dark:bg-[#10141F]">
          <ScanLine className="mx-auto h-7 w-7 text-slate-400 dark:text-[#8F9AAF]" aria-hidden="true" />
          <p className="mt-3 text-base font-semibold text-[#030616] dark:text-[#EEF1F8]">
            No unmatched partner scans
          </p>
          <p className="mt-1 text-sm text-[#48556A] dark:text-[#A6B0C3]">
            All ingested DEXASCAN body composition records are bound to clinic patients.
          </p>
        </div>
      )}

      {scans &&
        scans.map((scan) => (
          <section
            key={scan.id}
            aria-label={`Unmatched scan ${scan.partner_scan_id}`}
            className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm dark:border-[#222838] dark:bg-[#10141F]"
          >
            <div className="flex flex-wrap items-start justify-between gap-4">
              <div>
                <div className="flex flex-wrap items-center gap-2.5">
                  <h2 className="text-base font-bold text-[#030616] dark:text-[#EEF1F8]">
                    {scan.partner_scan_id} (v{scan.partner_scan_version})
                  </h2>
                  <span className="rounded-full bg-[#FBEFD8] px-3 py-0.5 text-xs font-semibold text-[#8A4F00] dark:bg-[#2F220D] dark:text-[#F2B65A]">
                    Unmatched
                  </span>
                </div>
                <p className="mt-1 text-xs text-[#48556A] dark:text-[#A6B0C3]">
                  Partner Patient ID: <strong className="tabular-nums">{scan.partner_patient_id}</strong> · Submitted
                  Zyndio ID:{' '}
                  <strong className="tabular-nums">{scan.zyndio_patient_id ?? 'None provided'}</strong> · Scan Date:{' '}
                  <strong className="tabular-nums">{scan.scan_date}</strong>
                </p>
                <p className="mt-1 text-xs text-slate-500 dark:text-[#8F9AAF]">
                  Scanner: {scan.device_vendor} {scan.device_model} ({scan.software_version})
                  {scan.site_id ? ` · Site ${scan.site_id}` : ''}
                </p>
              </div>

              <div className="flex flex-wrap gap-3 text-xs tabular-nums text-[#030616] dark:text-[#EEF1F8]">
                {scan.measures.weight_lb !== undefined && scan.measures.weight_lb !== null && (
                  <span className="rounded-lg bg-slate-100 px-2.5 py-1 dark:bg-[#1A2130]">
                    Weight: <strong>{scan.measures.weight_lb} lb</strong>
                  </span>
                )}
                {scan.measures.fat_mass_lb !== undefined && scan.measures.fat_mass_lb !== null && (
                  <span className="rounded-lg bg-slate-100 px-2.5 py-1 dark:bg-[#1A2130]">
                    Fat Mass: <strong>{scan.measures.fat_mass_lb} lb</strong>
                  </span>
                )}
                {scan.measures.lean_mass_lb !== undefined && scan.measures.lean_mass_lb !== null && (
                  <span className="rounded-lg bg-slate-100 px-2.5 py-1 dark:bg-[#1A2130]">
                    Lean Mass: <strong>{scan.measures.lean_mass_lb} lb</strong>
                  </span>
                )}
              </div>
            </div>

            {canBind && (
              <div className="mt-4 flex flex-wrap items-center gap-3 border-t border-slate-100 pt-4 dark:border-[#222838]">
                <label
                  htmlFor={`bind-select-${scan.id}`}
                  className="text-xs font-semibold text-[#48556A] dark:text-[#A6B0C3]"
                >
                  Bind to clinic patient:
                </label>
                <select
                  id={`bind-select-${scan.id}`}
                  aria-label={`Select patient for scan ${scan.partner_scan_id}`}
                  value={selectedPatientByScan[scan.id] ?? ''}
                  onChange={(e) =>
                    setSelectedPatientByScan((prev) => ({
                      ...prev,
                      [scan.id]: e.target.value,
                    }))
                  }
                  className="min-h-[44px] rounded-xl border border-slate-300 bg-white px-3.5 text-sm text-[#030616] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2] dark:border-[#6C7690] dark:bg-[#0B0F19] dark:text-[#EEF1F8]"
                >
                  {patients.map((p) => (
                    <option key={p.patientId} value={p.patientId}>
                      {p.displayName} ({p.mrn})
                    </option>
                  ))}
                </select>

                <button
                  type="button"
                  aria-label={`Bind scan ${scan.partner_scan_id}`}
                  disabled={busyScanId === scan.id || !selectedPatientByScan[scan.id]}
                  onClick={() => handleBind(scan)}
                  className="inline-flex min-h-[44px] items-center gap-2 rounded-full bg-[#2C5CF2] px-5 text-sm font-semibold text-white hover:bg-[#2450D8] disabled:cursor-not-allowed disabled:opacity-40 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2]"
                >
                  <Link2 className="h-4 w-4" aria-hidden="true" />
                  Bind to Patient
                </button>
              </div>
            )}
          </section>
        ))}
    </div>
  );
};

export default UnmatchedRecordsQueue;
