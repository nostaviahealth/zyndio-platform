// Build-time web feature flags (Vite env, read at call time so tests can
// vi.stubEnv them). Every flag here is OFF unless explicitly set to "true".

/**
 * VITE_FEATURE_LEGACY_PATIENT_SCREENS (TC-026, Henry 2 Nov): the four legacy
 * screens moved off `profiles` in PR #25 - patient portal HealthQuestionnaire
 * (#/questionnaire) and LabTestUpload (#/lab-test), and staff PatientDetail
 * (#/admin/patient/:id, hosts HealthJourneyPanel) and NutritionLab
 * (#/admin/nutrition-lab) - do not work end to end yet (no real persistence;
 * Clara M3). Until that is carded and built they are hidden: with the flag off
 * their routes are not registered and no nav entry/button links to them.
 */
export function isLegacyPatientScreensEnabled(): boolean {
  return import.meta.env.VITE_FEATURE_LEGACY_PATIENT_SCREENS === 'true';
}

/** Paths that exist only while VITE_FEATURE_LEGACY_PATIENT_SCREENS is on. */
export const LEGACY_PATIENT_SCREEN_PATHS = ['/questionnaire', '/lab-test'] as const;
