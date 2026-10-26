// Shared env/skip gate for tests/integration/*.test.ts. Reads local
// Supabase connection details from the process env only (never a file) -
// scripts/integration-local.sh and the CI `supabase` job are responsible
// for exporting these before vitest runs.
//
// - CI=true and any of the three required vars missing -> hard failure.
// - Not CI and missing -> suites skip, with a visible console message.

export const SUPABASE_URL = process.env.SUPABASE_URL;
export const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;
export const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
// Not one of the three required vars (admin-actions.test.ts only); derived
// from SUPABASE_URL if a dev shell didn't export it explicitly.
export const SUPABASE_FUNCTIONS_URL =
  process.env.SUPABASE_FUNCTIONS_URL ?? (SUPABASE_URL ? `${SUPABASE_URL}/functions/v1` : undefined);

const missing = [
  ['SUPABASE_URL', SUPABASE_URL],
  ['SUPABASE_ANON_KEY', SUPABASE_ANON_KEY],
  ['SUPABASE_SERVICE_ROLE_KEY', SUPABASE_SERVICE_ROLE_KEY],
]
  .filter(([, value]) => !value)
  .map(([name]) => name);

export const integrationEnvReady = missing.length === 0;

if (!integrationEnvReady) {
  const message =
    `tests/integration: missing env var(s) ${missing.join(', ')} - ` +
    'start local Supabase and run via scripts/integration-local.sh (or export ' +
    '`supabase status -o env` yourself) to exercise these suites.';

  if (process.env.CI === 'true') {
    throw new Error(`${message} CI=true requires a running local stack - failing hard.`);
  }

  // eslint-disable-next-line no-console
  console.warn(`SKIPPING: ${message}`);
}
