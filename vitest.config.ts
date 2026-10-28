import { defineConfig } from 'vitest/config';
import { configDefaults } from 'vitest/config';
import react from '@vitejs/plugin-react';

// Plain `npm test` / `vitest run` must never require a running Supabase
// stack - tests/integration/* only run via `npm run test:integration`
// (vitest.integration.config.ts), which has its own include/setup.
export default defineConfig({
  plugins: [react()],
  // Fictional, local-only placeholders so importing lib/supabase.ts under
  // vitest (which never loads the real .env) doesn't throw - every admin
  // auth test below mocks supabase.auth/.rpc/.functions itself rather than
  // hitting this URL.
  define: {
    'import.meta.env.VITE_SUPABASE_URL': JSON.stringify('http://127.0.0.1:54321'),
    'import.meta.env.VITE_SUPABASE_ANON_KEY': JSON.stringify('test-anon-key'),
  },
  test: {
    globals: true,
    // Only the admin-auth component tests need a DOM - each of those files
    // opts in itself via a `// @vitest-environment jsdom` docblock rather
    // than setting jsdom globally here, which triggers a real esbuild bug
    // (jsdom's TextEncoder breaks Vite's own node-side transforms for
    // unrelated node-environment tests such as src/theme/tokens.test.ts).
    setupFiles: ['./vitest.setup.ts'],
    exclude: [...configDefaults.exclude, 'tests/integration/**'],
  },
});
