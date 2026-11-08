import path from 'path';
import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

// TC-032: Tailwind (tailwind.config.ts + postcss.config.js, index.css) and the
// fonts are built into the bundle; index.html loads no external script/style.

export default defineConfig(({ mode }) => {
    const env = loadEnv(mode, '.', '');
    return {
      server: {
        port: 3000,
        host: '0.0.0.0',
      },
      plugins: [react()],
      define: {
        // Never inline a server-side secret here: everything in `define`
        // ships to every browser (tests/build-config/no-secret-defines.test.ts).
        __PREVIEW_BUILD__: mode === 'preview',
        // The preview/screenshot harness (build:preview) renders pages against
        // injected fixtures and never touches Supabase, but lib/supabase.ts
        // still calls createClient() at import, which throws on an empty URL.
        // Give the preview build placeholder values (real env when set) so the
        // harness boots; production builds are untouched and use real env.
        ...(mode === 'preview'
          ? {
              'import.meta.env.VITE_SUPABASE_URL': JSON.stringify(
                env.VITE_SUPABASE_URL || 'http://127.0.0.1:54321'
              ),
              'import.meta.env.VITE_SUPABASE_ANON_KEY': JSON.stringify(
                env.VITE_SUPABASE_ANON_KEY || 'preview-anon-key'
              ),
            }
          : {}),
      },
      resolve: {
        // TC-032: exactly one React copy in the bundle.
        dedupe: ['react', 'react-dom'],
        alias: {
          '@': path.resolve(__dirname, '.'),
        }
      }
    };
});
