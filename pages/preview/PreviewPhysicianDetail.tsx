import React from 'react';
import PhysicianPatientDetail from '../admin/clinic/PhysicianPatientDetail';
import { FlagKey } from '../../lib/clinicalApi';
import { detailFixtureApi, DETAIL_NOW, SINGLE_NOW, HSCRP_REVIEW_DETAILS } from './previewClinicalFixtures';
import { HBA1C_TREND_APPROVED, JORDAN_LATEST_APPROVED, recordFixtureApi } from './previewPortalFixtures';

// 02-patient-detail preview: renders the LIVE PhysicianPatientDetail component
// with a fixture ClinicalApi injected at the `api` boundary. State selects the
// fixture behaviour plus the few view-level inputs the harness controls (which
// marker is selected, header flags, needs-review provenance).
const PreviewPhysicianDetail: React.FC<{ state: string; mode: 'light' | 'dark' }> = ({ state, mode }) => {
  // POR-03..06 states: 'timeline', 'timeline-empty', 'brief',
  // 'approved-ranges' (caveat replaced), 'read-only' (export blocked).
  const base = detailFixtureApi(state);
  const api = state === 'approved-ranges' ? { ...base, fetchLatestResults: async () => JORDAN_LATEST_APPROVED, fetchTrend: async () => HBA1C_TREND_APPROVED } : base;
  const initialTab = state.startsWith('timeline') ? 'timeline' : state === 'brief' ? 'brief' : 'labs';
  const now = state === 'single' ? SINGLE_NOW : DETAIL_NOW;
  const flags: FlagKey[] = state === 'single' ? [] : ['question_waiting'];
  const questionsCount = state === 'single' ? undefined : 1;
  const initialSelectedKey = state === 'needs-review' ? 'hscrp' : undefined;
  const reviewDetails = state === 'needs-review' ? HSCRP_REVIEW_DETAILS : undefined;
  return (
    <PhysicianPatientDetail
      api={api}
      now={now}
      mode={mode}
      patientId="p-jordan"
      flags={flags}
      questionsCount={questionsCount}
      initialSelectedKey={initialSelectedKey}
      reviewDetails={reviewDetails}
      recordApi={recordFixtureApi(state)}
      viewerRole={state === 'read-only' ? 'read_only' : 'physician'}
      initialTab={initialTab}
      onDownload={() => undefined}
    />
  );
};

export default PreviewPhysicianDetail;
