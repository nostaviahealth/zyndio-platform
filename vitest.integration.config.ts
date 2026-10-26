import { defineConfig } from 'vitest/config';

// `npm run test:integration` only - needs a running local Supabase stack
// (supabase start) and `supabase functions serve` for the admin-actions
// suite. See scripts/integration-local.sh.
export default defineConfig({
  test: {
    include: ['tests/integration/**/*.test.ts'],
    testTimeout: 30000,
    hookTimeout: 30000,
    fileParallelism: false,
  },
});
