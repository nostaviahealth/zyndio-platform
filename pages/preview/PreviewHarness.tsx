import React from 'react';
import { useSearchParams } from 'react-router-dom';
import PreviewUsersRoles from './PreviewUsersRoles';
import { PREVIEW_FIXTURE_MARKER } from './previewFixtures';

// /__preview?screen=&state=&mode= - screenshot harness for scripts/
// demo_screenshots_admin.py, built only behind __PREVIEW_BUILD__ (see
// vite.config.ts / `npm run build:preview`). Only 07-users-roles (this
// step's screen) is wired up; 01-06 were built in earlier steps without a
// preview-fixture path and are left for a follow-up rather than reworking
// already-shipped, already-tested pages under this step's time box.
const SCREENS: Record<string, React.FC<{ state: string }>> = {
  '07-users-roles': PreviewUsersRoles,
};

const PreviewHarness: React.FC = () => {
  const [params] = useSearchParams();
  const screen = params.get('screen') ?? '07-users-roles';
  const state = params.get('state') ?? 'default';
  const mode = params.get('mode') ?? 'light';
  const Screen = SCREENS[screen];

  if (!Screen) {
    return <div style={{ padding: 24 }}>Unknown preview screen: {screen}</div>;
  }

  const isDark = mode === 'dark';

  return (
    <div
      data-preview-mode={mode}
      data-preview-marker={PREVIEW_FIXTURE_MARKER}
      style={{
        minHeight: '100vh',
        background: isDark ? '#030616' : '#F2F4F7',
        color: isDark ? '#F2F4F7' : undefined,
        padding: '32px 40px',
      }}
    >
      <Screen state={state} />
    </div>
  );
};

export default PreviewHarness;
