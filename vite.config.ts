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
      },
      resolve: {
        alias: {
          '@': path.resolve(__dirname, '.'),
        }
      }
    };
});
