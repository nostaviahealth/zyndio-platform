import React from 'react';
import PhysicianRoster from '../admin/clinic/PhysicianRoster';
import { RosterFilter, RosterSort } from '../../lib/clinicalApi';
import { rosterFixtureApi, ROSTER_NOW } from './previewClinicalFixtures';

// 01-patient-list preview: renders the LIVE PhysicianRoster component with a
// fixture ClinicalApi injected at the `api` boundary (not a look-alike). The
// state selects which fixture behaviour the API presents.
const PreviewPhysicianRoster: React.FC<{ state: string }> = ({ state }) => {
  const api = rosterFixtureApi(state);
  const initialSearch = state === 'no-results' ? 'Rivra' : '';
  const initialFilter: RosterFilter = state === 'filtered' ? 'questions_waiting' : 'all';
  const initialSort: RosterSort = state === 'filtered' ? 'questions_waiting' : 'recent';
  return (
    <PhysicianRoster
      api={api}
      now={ROSTER_NOW}
      role="physician"
      initialSearch={initialSearch}
      initialFilter={initialFilter}
      initialSort={initialSort}
    />
  );
};

export default PreviewPhysicianRoster;
