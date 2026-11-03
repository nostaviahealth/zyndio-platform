// @vitest-environment jsdom
// TC-026 (Henry, 2 Nov, PR #25 review round): the four legacy screens -
// HealthQuestionnaire (#/questionnaire), LabTestUpload (#/lab-test),
// PatientDetail (#/admin/patient/:id) and NutritionLab (#/admin/nutrition-lab)
// - sit behind VITE_FEATURE_LEGACY_PATIENT_SCREENS, OFF by default. With the
// flag off their routes are not registered (the URL falls through to the
// catch-all) and no button or notification links to them.
import React from 'react';
import fs from 'node:fs';
import path from 'node:path';
import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { MemoryRouter, Routes, Route, useLocation } from 'react-router-dom';

vi.mock('../../pages/HealthQuestionnaire', () => ({ default: () => <div>LEGACY_QUESTIONNAIRE_PAGE</div> }));
vi.mock('../../pages/LabTestUpload', () => ({ default: () => <div>LEGACY_LAB_TEST_PAGE</div> }));
vi.mock('../../pages/admin/PatientDetail', () => ({ default: () => <div>LEGACY_PATIENT_DETAIL_PAGE</div> }));
vi.mock('../../pages/admin/NutritionLab', () => ({ default: () => <div>LEGACY_NUTRITION_LAB_PAGE</div> }));
vi.mock('../../components/admin-shell/RequireRole', () => ({
  default: ({ children }: { children: React.ReactNode }) => <>{children}</>,
}));

const mockUseUser = vi.fn();
vi.mock('../../contexts/UserContext', () => ({ useUser: () => mockUseUser() }));
vi.mock('../../contexts/AuthContext', () => ({ useAuth: () => ({ user: { id: 'fictional-user-1' } }) }));
vi.mock('../../lib/supabase', () => ({ supabase: {} }));

const mockUseAdmin = vi.fn();
vi.mock('../../contexts/AdminContext', () => ({ useAdmin: () => mockUseAdmin() }));
const mockUsePortalAuth = vi.fn();
vi.mock('../../contexts/PortalAuthContext', () => ({ usePortalAuth: () => mockUsePortalAuth() }));

import { isLegacyPatientScreensEnabled } from '../../lib/featureFlags';
import { legacyAdminScreenRoutes, legacyPortalScreenRoutes } from '../../components/LegacyPatientScreenRoutes';
import Home from '../../pages/Home';
import Header from '../../components/Header';

const FLAG = 'VITE_FEATURE_LEGACY_PATIENT_SCREENS';

afterEach(() => {
  vi.unstubAllEnvs();
});

const LocationProbe: React.FC = () => <div data-testid="location">{useLocation().pathname}</div>;

// Mirrors App.tsx's shape: /admin children, "/" portal children, catch-all.
function renderAt(url: string) {
  return render(
    <MemoryRouter initialEntries={[url]}>
      <Routes>
        <Route path="/admin">
          <Route index element={<div>ADMIN_INDEX</div>} />
          {legacyAdminScreenRoutes()}
        </Route>
        <Route path="/">
          <Route index element={<div>PORTAL_HOME</div>} />
          {legacyPortalScreenRoutes()}
        </Route>
        <Route path="*" element={<div>CATCH_ALL</div>} />
      </Routes>
    </MemoryRouter>
  );
}

const LEGACY_URLS: Array<[string, string]> = [
  ['/questionnaire', 'LEGACY_QUESTIONNAIRE_PAGE'],
  ['/lab-test', 'LEGACY_LAB_TEST_PAGE'],
  ['/admin/patient/p-fictional-1', 'LEGACY_PATIENT_DETAIL_PAGE'],
  ['/admin/nutrition-lab', 'LEGACY_NUTRITION_LAB_PAGE'],
];

describe('VITE_FEATURE_LEGACY_PATIENT_SCREENS flag value', () => {
  it('is off by default (unset in the test/CI env)', () => {
    expect(isLegacyPatientScreensEnabled()).toBe(false);
  });

  it.each(['', 'false', '1', 'TRUE', 'yes'])('is off for %j (only exactly "true" turns it on)', (v) => {
    vi.stubEnv(FLAG, v);
    expect(isLegacyPatientScreensEnabled()).toBe(false);
  });

  it('is on only for "true"', () => {
    vi.stubEnv(FLAG, 'true');
    expect(isLegacyPatientScreensEnabled()).toBe(true);
  });
});

describe('legacy screen routes', () => {
  it('registers no routes when the flag is off', () => {
    expect(legacyAdminScreenRoutes()).toBeNull();
    expect(legacyPortalScreenRoutes()).toBeNull();
  });

  it.each(LEGACY_URLS)('flag off: %s is not reachable (falls to the catch-all)', (url, page) => {
    renderAt(url);
    expect(screen.queryByText(page)).not.toBeInTheDocument();
    expect(screen.getByText('CATCH_ALL')).toBeInTheDocument();
  });

  it.each(LEGACY_URLS)('flag on: %s renders its screen', (url, page) => {
    vi.stubEnv(FLAG, 'true');
    renderAt(url);
    expect(screen.getByText(page)).toBeInTheDocument();
  });

  it('App.tsx only mounts the four screens through the gated route helpers', () => {
    const app = fs.readFileSync(path.resolve(__dirname, '../../App.tsx'), 'utf8');
    for (const name of ['HealthQuestionnaire', 'LabTestUpload', 'PatientDetail', 'NutritionLab']) {
      expect(app).not.toMatch(new RegExp(`import ${name} from`));
      expect(app).not.toMatch(new RegExp(`<${name}\\b`));
    }
    expect(app).toContain('{legacyAdminScreenRoutes()}');
    expect(app).toContain('{legacyPortalScreenRoutes()}');
  });
});

describe('no entry points into hidden legacy screens', () => {
  const baseUser = {
    loading: false,
    publishedIntelligence: null,
    publishedJourney: null,
    hasAnyPublishedContent: () => false,
    currentPhase: null,
    getProtocolSection: () => null,
  };

  it.each([
    ['questionnaire_pending', /Start Questionnaire/],
    ['lab_test_scheduled', /Schedule Test/],
    ['profile_creation', /Start Questionnaire/],
  ])('Home (%s): flag off shows no button into the legacy screen', (stage, label) => {
    mockUseUser.mockReturnValue({ ...baseUser, patientProfile: { id: 'fictional-patient-1', stage } });
    render(<MemoryRouter><Home /></MemoryRouter>);
    expect(screen.queryByRole('button', { name: label })).not.toBeInTheDocument();
  });

  it('Home: flag on still offers "Start Questionnaire"', () => {
    vi.stubEnv(FLAG, 'true');
    mockUseUser.mockReturnValue({ ...baseUser, patientProfile: { id: 'fictional-patient-1', stage: 'questionnaire_pending' } });
    render(<MemoryRouter><Home /></MemoryRouter>);
    expect(screen.getByRole('button', { name: /Start Questionnaire/ })).toBeInTheDocument();
  });

  function clickWelcomeNotification() {
    mockUseUser.mockReturnValue({ ...baseUser, patientProfile: { id: 'fictional-patient-1', stage: 'profile_creation' } });
    render(
      <MemoryRouter initialEntries={['/']}>
        <Header title="Home" />
        <LocationProbe />
      </MemoryRouter>
    );
    fireEvent.click(screen.getAllByRole('button')[0]); // notification bell
    fireEvent.click(screen.getByText('Welcome to Zyndio'));
    return screen.getByTestId('location').textContent;
  }

  it('Header: flag off, the welcome notification does not navigate to /questionnaire', () => {
    expect(clickWelcomeNotification()).toBe('/');
  });

  it('Header: flag on, the welcome notification still goes to /questionnaire', () => {
    vi.stubEnv(FLAG, 'true');
    expect(clickWelcomeNotification()).toBe('/questionnaire');
  });

  // Merge of #25 into #26 (TC-029): #26 deleted AdminDashboard, the only
  // non-legacy page that had a "View Details" link to the legacy
  // #/admin/patient/:id. The old render test ("flag off hides View Details")
  // has no host page left, so it is replaced by a static guard: no non-legacy
  // source file links to /admin/patient/ at all, flag on or off. The legacy
  // screens themselves (and the route table) may still.
  //
  // TC-030 item 15 (Clara PR #26 r2, L-r2-1): the first guard only walked
  // pages/ and components/ and only matched the ABSOLUTE "/admin/patient/"
  // form, so a relative link ("patient/${id}" inside the /admin subtree) or a
  // link hidden in App.tsx / contexts / hooks / lib / src / utils slipped
  // through (Clara's mutant passed). Widen the walk to the whole web source
  // tree and anchor the match on a quoted path LITERAL that targets the legacy
  // detail screen - absolute "/admin/patient/<id>" or relative "patient/<id>".
  it('no non-legacy source file links to the legacy patient detail (absolute /admin/patient/ or relative patient/:id)', () => {
    const LEGACY_FILES = new Set([
      'pages/HealthQuestionnaire.tsx',
      'pages/LabTestUpload.tsx',
      'pages/admin/PatientDetail.tsx',
      'pages/admin/NutritionLab.tsx',
      'components/LegacyPatientScreenRoutes.tsx',
    ]);
    const root = path.resolve(__dirname, '../..');
    const walk = (dir: string): string[] => {
      const abs = path.join(root, dir);
      if (!fs.existsSync(abs)) return [];
      return fs.readdirSync(abs, { withFileTypes: true }).flatMap((e) => {
        const rel = `${dir}/${e.name}`;
        if (e.isDirectory()) return walk(rel);
        return /\.(tsx?|jsx?)$/.test(e.name) && !/\.(test|spec)\./.test(e.name) ? [rel] : [];
      });
    };
    const SOURCE_DIRS = ['pages', 'components', 'contexts', 'hooks', 'lib', 'src', 'utils'];
    const ROOT_FILES = ['App.tsx', 'constants.ts', 'index.tsx', 'types.ts'];
    const files = [
      ...ROOT_FILES.filter((f) => fs.existsSync(path.join(root, f))),
      ...SOURCE_DIRS.flatMap(walk),
    ].filter((f) => !LEGACY_FILES.has(f));
    expect(files.length).toBeGreaterThan(20);
    // Coverage now reaches beyond pages/ and components/ (incl. the App.tsx
    // route table), per L-r2-1.
    expect(files).toContain('App.tsx');
    expect(files.some((f) => !f.startsWith('pages/') && !f.startsWith('components/'))).toBe(true);
    // A quote/backtick-anchored path literal for the legacy patient detail
    // screen: absolute "/admin/patient/<id>" or relative "patient/<id>".
    // Anchoring on the opening quote skips prose mentions in comments
    // ("/admin/patient/:id", "patient/user data") and the plural "patients/"
    // roster route, which carry no quote immediately before "patient/".
    const LEGACY_LINK = /['"`](?:\/admin\/)?patient\//;
    const offenders = files.filter((f) => LEGACY_LINK.test(fs.readFileSync(path.join(root, f), 'utf8')));
    expect(offenders).toEqual([]);
  });
});
