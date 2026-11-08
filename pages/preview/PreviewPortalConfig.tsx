import React from 'react';
import ReferenceRanges from '../admin/clinic/ReferenceRanges';
import PlanModules from '../admin/PlanModules';
import { planFixtureApi, rangesFixtureApi } from './previewPortalFixtures';

// 08-reference-ranges (POR-05) and 09-plan-modules (PP-01) previews: the LIVE
// page components with fixture APIs injected.
export const PreviewReferenceRanges: React.FC<{ state: string; mode: 'light' | 'dark' }> = ({ state }) => (
  <ReferenceRanges api={rangesFixtureApi(state)} viewerRole={state === 'read-only' ? 'read_only' : 'physician'} />
);

export const PreviewPlanModules: React.FC<{ state: string; mode: 'light' | 'dark' }> = () => (
  <PlanModules api={planFixtureApi()} />
);
