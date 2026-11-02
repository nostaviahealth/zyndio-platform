import React from 'react';
import { Route } from 'react-router-dom';
import RequireRole from './admin-shell/RequireRole';
import HealthQuestionnaire from '../pages/HealthQuestionnaire';
import LabTestUpload from '../pages/LabTestUpload';
import PatientDetail from '../pages/admin/PatientDetail';
import NutritionLab from '../pages/admin/NutritionLab';
import { isLegacyPatientScreensEnabled } from '../lib/featureFlags';

// TC-026 (Henry 2 Nov): the four legacy screens are registered as routes only
// when VITE_FEATURE_LEGACY_PATIENT_SCREENS is "true" (see lib/featureFlags.ts).
// With the flag off these return null so the paths fall through to the app's
// catch-all redirect - they are not reachable by URL at all. (A Fragment of
// <Route>s is flattened by react-router's createRoutesFromChildren.)

/** Children of the /admin AppShell route (relative paths). */
export function legacyAdminScreenRoutes(enabled: boolean = isLegacyPatientScreensEnabled()): React.ReactElement | null {
  if (!enabled) return null;
  return (
    <>
    <Route
      path="patient/:id"
      element={
        <RequireRole roles={['physician', 'care_coordinator']}>
          <PatientDetail />
        </RequireRole>
      }
    />
    <Route
      path="nutrition-lab"
      element={
        <RequireRole roles={['physician', 'care_coordinator']}>
          <NutritionLab />
        </RequireRole>
      }
    />
    </>
  );
}

/** Children of the patient portal "/" Layout route (relative paths). */
export function legacyPortalScreenRoutes(enabled: boolean = isLegacyPatientScreensEnabled()): React.ReactElement | null {
  if (!enabled) return null;
  return (
    <>
    <Route path="questionnaire" element={<HealthQuestionnaire />} />
    <Route path="lab-test" element={<LabTestUpload />} />
    </>
  );
}
