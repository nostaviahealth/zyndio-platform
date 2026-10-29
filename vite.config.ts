import path from 'path';
import { defineConfig, loadEnv, type Plugin } from 'vite';
import react from '@vitejs/plugin-react';
import { buildTailwindTheme } from './src/theme/tokens';

const THEME_MARKER = '/*ZYNDIO_BRAND_THEME*/{}';

function zyndioThemePlugin(): Plugin {
  return {
    name: 'zyndio-brand-theme',
    transformIndexHtml(html) {
      return html.replace(THEME_MARKER, JSON.stringify(buildTailwindTheme()));
    },
  };
}

export default defineConfig(({ mode }) => {
    const env = loadEnv(mode, '.', '');
    return {
      server: {
        port: 3000,
        host: '0.0.0.0',
      },
      plugins: [react(), zyndioThemePlugin()],
      define: {
        'process.env.API_KEY': JSON.stringify(env.GEMINI_API_KEY),
        'process.env.GEMINI_API_KEY': JSON.stringify(env.GEMINI_API_KEY),
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
        alias: {
          '@': path.resolve(__dirname, '.'),
        }
      }
    };
});
