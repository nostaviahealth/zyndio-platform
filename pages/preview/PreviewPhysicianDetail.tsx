import React from 'react';
import PhysicianPatientDetail from '../admin/clinic/PhysicianPatientDetail';
import { FlagKey } from '../../lib/clinicalApi';
import { detailFixtureApi, DETAIL_NOW, SINGLE_NOW, HSCRP_REVIEW_DETAILS } from './previewClinicalFixtures';

// 02-patient-detail preview: renders the LIVE PhysicianPatientDetail component
// with a fixture ClinicalApi injected at the `api` boundary. State selects the
// fixture behaviour plus the few view-level inputs the harness controls (which
// marker is selected, header flags, needs-review provenance).
const PreviewPhysicianDetail: React.FC<{ state: string; mode: 'light' | 'dark' }> = ({ state, mode }) => {
  const api = detailFixtureApi(state);
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
    />
  );
};

export default PreviewPhysicianDetail;
