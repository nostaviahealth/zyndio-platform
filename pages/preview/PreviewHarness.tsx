import React from 'react';
import { useSearchParams } from 'react-router-dom';
import PreviewUsersRoles from './PreviewUsersRoles';
import PreviewPhysicianRoster from './PreviewPhysicianRoster';
import PreviewPhysicianDetail from './PreviewPhysicianDetail';
import PreviewShell from './PreviewShell';
import { PreviewPlanModules, PreviewReferenceRanges } from './PreviewPortalConfig';
import { PREVIEW_FIXTURE_MARKER } from './previewFixtures';

// /__preview?screen=&state=&mode= - screenshot harness for scripts/
// demo_screenshots_admin.py, built only behind __PREVIEW_BUILD__ (see
// vite.config.ts / `npm run build:preview`). The clinical screens (01/02)
// render the LIVE page components with a fixture ClinicalApi injected; the
// admin screen (07) keeps its TC-014 look-alike.
interface ScreenDef {
  Component: React.FC<{ state: string; mode: 'light' | 'dark' }>;
  variant: 'admin' | 'clinical';
}

const SCREENS: Record<string, ScreenDef> = {
  '01-patient-list': { Component: PreviewPhysicianRoster, variant: 'clinical' },
  '02-patient-detail': { Component: PreviewPhysicianDetail, variant: 'clinical' },
  '07-users-roles': { Component: PreviewUsersRoles, variant: 'admin' },
  '08-reference-ranges': { Component: PreviewReferenceRanges, variant: 'clinical' },
  '09-plan-modules': { Component: PreviewPlanModules, variant: 'admin' },
};

const PreviewHarness: React.FC = () => {
  const [params] = useSearchParams();
  const screen = params.get('screen') ?? '01-patient-list';
  const state = params.get('state') ?? 'default';
  const mode = params.get('mode') ?? 'light';
  const def = SCREENS[screen];

  if (!def) {
    return <div style={{ padding: 24 }}>Unknown preview screen: {screen}</div>;
  }

  const normalizedMode: 'light' | 'dark' = mode === 'dark' ? 'dark' : 'light';
  const { Component, variant } = def;

  return (
    <div data-preview-mode={mode} data-preview-marker={PREVIEW_FIXTURE_MARKER}>
      <PreviewShell mode={normalizedMode} variant={variant} showFictionalTag={variant === 'admin'}>
        <Component state={state} mode={normalizedMode} />
      </PreviewShell>
    </div>
  );
};

export default PreviewHarness;
