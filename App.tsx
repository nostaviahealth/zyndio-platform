import React from 'react';
import { HashRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './contexts/AuthContext';
import { AdminProvider } from './contexts/AdminContext';
import { SidebarProvider } from './contexts/SidebarContext';
import { UserProvider } from './contexts/UserContext';
import { PortalAuthProvider } from './contexts/PortalAuthContext';
import ProtectedRoute from './components/ProtectedRoute';
import RequireSession from './components/admin-shell/RequireSession';
import RequireRole from './components/admin-shell/RequireRole';
import AppShell from './components/admin-shell/AppShell';
import AdminIndex from './components/admin-shell/AdminIndex';
import Layout from './components/Layout';
import ErrorBoundary from './components/ErrorBoundary';
import Home from './pages/Home';
import Protocol from './pages/Protocol';
import HealthData from './pages/HealthData';
import FoodIntelligence from './pages/FoodIntelligence';

import Devices from './pages/Devices';
import Intelligence from './pages/Intelligence';
import HealthDomains from './pages/HealthDomains';
import DiseaseRiskAnalysis from './pages/DiseaseRiskAnalysis';
import Chat from './pages/Chat';
import Tools from './pages/Tools';
import Settings from './pages/Settings';
import Login from './pages/Login';
import CreatePatient from './pages/admin/CreatePatient';
import NutritionWorkbench from './pages/admin/NutritionWorkbench';
import { legacyAdminScreenRoutes, legacyPortalScreenRoutes } from './components/LegacyPatientScreenRoutes';
import UsersRoles from './pages/admin/UsersRoles';
import PhysicianRoster from './pages/admin/clinic/PhysicianRoster';
import PhysicianPatientDetail from './pages/admin/clinic/PhysicianPatientDetail';
import OutcomesReviewQueue from './pages/admin/clinic/OutcomesReviewQueue';
import UnmatchedRecordsQueue from './pages/admin/clinic/UnmatchedRecordsQueue';
import SignIn from './pages/admin/SignIn';
import AcceptInvite from './pages/admin/AcceptInvite';
import ResetPassword from './pages/admin/ResetPassword';
import ChangePassword from './pages/admin/ChangePassword';
import TwoFactorSetup from './pages/admin/TwoFactorSetup';
import TwoFactorChallenge from './pages/admin/TwoFactorChallenge';
import RecoverySignIn from './pages/admin/RecoverySignIn';
import SessionExpired from './pages/admin/SessionExpired';
import SessionEndedByAdmin from './pages/admin/SessionEndedByAdmin';
import HealthVault from './pages/HealthVault';
import GutMicrobiomeDetail from './pages/panels/GutMicrobiomeDetail';
import GeneticPanelDetail from './pages/panels/GeneticPanelDetail';
import BiologicalAgeDetail from './pages/panels/BiologicalAgeDetail';
import HeavyMetalsDetail from './pages/panels/HeavyMetalsDetail';
import ToxicityDetail from './pages/panels/ToxicityDetail';

// __PREVIEW_BUILD__ is a build-time literal (false outside `vite build
// --mode preview` / `npm run build:preview`) - gating both the route and
// the dynamic import means rollup's dead-code elimination drops the
// /__preview harness (and its fixture strings) from the default
// `npm run build` bundle entirely. See tests/preview-harness.test.ts.
const LazyPreviewHarness = __PREVIEW_BUILD__ ? React.lazy(() => import('./pages/preview/PreviewHarness')) : null;

// Placeholder for missing pages
const Profile = () => <div className="p-8">Profile Page Coming Soon</div>;

const App: React.FC = () => {
  return (
    <ErrorBoundary>
      <Router>
        <AuthProvider>
          <PortalAuthProvider>
          <AdminProvider>
            <SidebarProvider>
              <Routes>
                {/* Public Routes */}
                <Route path="/login" element={<Login />} />

                {/* Admin auth routes (TC-005): sign-in, invite accept, 2FA setup/challenge/recovery */}
                <Route path="/admin/login" element={<SignIn />} />
                <Route path="/admin/invite/:token" element={<AcceptInvite />} />
                <Route path="/admin/reset-password" element={<ResetPassword />} />
                <Route
                  path="/admin/change-password"
                  element={
                    <RequireSession>
                      <ChangePassword />
                    </RequireSession>
                  }
                />
                <Route
                  path="/admin/2fa/setup"
                  element={
                    <RequireSession requireAal2={false}>
                      <TwoFactorSetup />
                    </RequireSession>
                  }
                />
                <Route
                  path="/admin/2fa/challenge"
                  element={
                    <RequireSession requireAal2={false}>
                      <TwoFactorChallenge />
                    </RequireSession>
                  }
                />
                <Route
                  path="/admin/2fa/recovery"
                  element={
                    <RequireSession requireAal2={false}>
                      <RecoverySignIn />
                    </RequireSession>
                  }
                />
                <Route path="/admin/session-expired" element={<SessionExpired />} />
                <Route path="/admin/session-ended" element={<SessionEndedByAdmin />} />

                {/* Admin Portal Routes - Protected, role-gated per route (06-access-denied
                    renders in place for the wrong role rather than redirecting). */}
                <Route
                  path="/admin"
                  element={
                    <RequireSession>
                      <AppShell />
                    </RequireSession>
                  }
                >
                  <Route index element={<AdminIndex />} />
                  {/* TC-015 physician portal: clinical roster + patient detail
                      (Labs tab). /admin/patients namespace to avoid the legacy
                      /admin/patient/:id route. read_only can view the roster
                      and detail/trends for their own clinic (Leo ruling, fix
                      round 28 Oct). */}
                  <Route
                    path="patients"
                    element={
                      <RequireRole roles={['physician', 'care_coordinator', 'read_only']}>
                        <PhysicianRoster />
                      </RequireRole>
                    }
                  />
                  <Route
                    path="patients/:id"
                    element={
                      <RequireRole roles={['physician', 'care_coordinator', 'read_only']}>
                        <PhysicianPatientDetail />
                      </RequireRole>
                    }
                  />
                  {/* TC-029 (a): patient creation is a care_coordinator task.
                      A physician must never see a create-patient button - and
                      the CreatePatient page itself carries one ("Create
                      Patient"), so physician is gated out of the route too, not
                      just the roster entry point. */}
                  <Route
                    path="patients/create"
                    element={
                      <RequireRole roles={['care_coordinator']}>
                        <CreatePatient />
                      </RequireRole>
                    }
                  />
                  <Route
                    path="nutrition"
                    element={
                      <RequireRole roles={['physician', 'care_coordinator']}>
                        <NutritionWorkbench />
                      </RequireRole>
                    }
                  />
                  <Route
                    path="outcomes"
                    element={
                      <RequireRole roles={['physician', 'care_coordinator', 'read_only']}>
                        <OutcomesReviewQueue />
                      </RequireRole>
                    }
                  />
                  <Route
                    path="unmatched-scans"
                    element={
                      <RequireRole roles={['physician', 'care_coordinator']}>
                        <UnmatchedRecordsQueue />
                      </RequireRole>
                    }
                  />
                  {/* Legacy patient/:id + nutrition-lab: only behind
                      VITE_FEATURE_LEGACY_PATIENT_SCREENS (off by default). */}
                  {legacyAdminScreenRoutes()}
                  <Route
                    path="users"
                    element={
                      <RequireRole roles={['org_admin']} pageLabel="Users and roles">
                        <UsersRoles />
                      </RequireRole>
                    }
                  />
                  {/* TC-030 (0b): unknown /admin/* paths (old bookmarks, email
                      links, routes hidden behind the legacy flag) must land on
                      the staff home, never fall through the global catch-all to
                      the patient portal ("Welcome to Zyndio"). */}
                  <Route path="*" element={<Navigate to="/admin" replace />} />
                </Route>

                {/* User Portal Routes - Protected */}
                <Route
                  path="/"
                  element={
                    <ProtectedRoute>
                      <UserProvider>
                        <Layout />
                      </UserProvider>
                    </ProtectedRoute>
                  }
                >
                  <Route index element={<Home />} />
                  <Route path="health-data" element={<HealthData />} />
                  <Route path="intelligence" element={<Intelligence />} />
                  <Route path="intelligence/domains" element={<HealthDomains />} />
                  <Route path="intelligence/risks" element={<DiseaseRiskAnalysis />} />

                  <Route path="protocol" element={<Protocol />} />
                  <Route path="devices" element={<Devices />} />
                  <Route path="tools" element={<Tools />} />
                  <Route path="settings" element={<Settings />} />
                  <Route path="chat" element={<Chat />} />
                  <Route path="profile" element={<Profile />} />
                  {/* Legacy questionnaire + lab-test: only behind
                      VITE_FEATURE_LEGACY_PATIENT_SCREENS (off by default). */}
                  {legacyPortalScreenRoutes()}
                  <Route path="food-intelligence" element={<FoodIntelligence />} />
                  <Route path="health-vault" element={<HealthVault />} />
                  <Route path="health-vault/gut-microbiome" element={<GutMicrobiomeDetail />} />
                  <Route path="health-vault/genetic" element={<GeneticPanelDetail />} />
                  <Route path="health-vault/biological-age" element={<BiologicalAgeDetail />} />
                  <Route path="health-vault/heavy-metals" element={<HeavyMetalsDetail />} />
                  <Route path="health-vault/toxicity" element={<ToxicityDetail />} />
                </Route>

                {/* Screenshot harness, build:preview only (OVERRIDES #8). */}
                {__PREVIEW_BUILD__ && LazyPreviewHarness && (
                  <Route
                    path="/__preview"
                    element={
                      <React.Suspense fallback={null}>
                        <LazyPreviewHarness />
                      </React.Suspense>
                    }
                  />
                )}

                {/* Catch all - redirect to home */}
                <Route path="*" element={<Navigate to="/" replace />} />
              </Routes>
            </SidebarProvider>
          </AdminProvider>
          </PortalAuthProvider>
        </AuthProvider>
      </Router>
    </ErrorBoundary>
  );
};

export default App;