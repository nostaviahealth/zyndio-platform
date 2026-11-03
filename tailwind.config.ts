import type { Config } from 'tailwindcss';
import { buildTailwindTheme } from './src/theme/tokens';

// TC-032: Tailwind is compiled at build time (was the unpinned Play CDN in
// index.html). Same config the CDN got, unchanged: darkMode variant, the two
// custom shadows, and the Zyndio brand theme from design tokens.

// Class names built at runtime (`bg-${color}-100` / `text-${color}-600` in
// pages/admin/PatientDetail.tsx, pages/admin/HealthJourneyPanel.tsx and
// pages/Home.tsx). The CDN JIT saw them in the DOM; a build only sees source,
// so they are listed here. Keep in sync with the `color:` values in those files.
export const DYNAMIC_ACCENT_COLORS = [
  'amber', 'blue', 'emerald', 'green', 'indigo', 'orange', 'purple', 'red', 'rose',
] as const;

const config: Config = {
  content: [
    './index.html',
    './*.{ts,tsx}',
    './{components,pages,contexts,hooks,lib,utils,src,constants}/**/*.{ts,tsx,js,jsx}',
  ],
  safelist: DYNAMIC_ACCENT_COLORS.flatMap((c) => [`bg-${c}-100`, `text-${c}-600`]),
  // TC-019: `dark:` applies under <html class="dark">, except inside a
  // `.light` surface (AuthCard: sign-in/2FA have no dark design yet).
  darkMode: ['variant', '&:is(.dark *):not(.light *)'],
  theme: {
    // Cast: ZyndioTailwindTheme's interfaces have no index signature, which
    // Tailwind's recursive key/value type wants; the values are plain strings.
    extend: Object.assign(
      {
        boxShadow: {
          soft: '0 4px 20px -2px rgba(0, 0, 0, 0.05)',
          glow: '0 0 15px rgba(139, 92, 246, 0.3)',
        },
      },
      buildTailwindTheme(),
    ) as unknown as NonNullable<Config['theme']>['extend'],
  },
  plugins: [],
};

export default config;
