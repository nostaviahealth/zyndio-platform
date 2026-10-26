import { defineConfig } from 'vitest/config';
import { configDefaults } from 'vitest/config';

// Plain `npm test` / `vitest run` must never require a running Supabase
// stack - tests/integration/* only run via `npm run test:integration`
// (vitest.integration.config.ts), which has its own include/setup.
export default defineConfig({
  test: {
    exclude: [...configDefaults.exclude, 'tests/integration/**'],
  },
});
