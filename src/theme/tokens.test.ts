import { describe, expect, it } from 'vitest';
import { buildTailwindTheme } from './tokens';

const HEX_COLOR = /^#[0-9a-fA-F]{6}$/;

describe('buildTailwindTheme', () => {
  const theme = buildTailwindTheme();

  it('maps every existing brand-* key onto the Zyndio design tokens', () => {
    expect(theme.colors.brand).toEqual({
      dark: '#030616', // text.primary
      blue: '#2C5CF2', // brand.primary
      sage: '#DEEAFC', // brand.subtle
      sageDark: '#2346DD', // brand.onSubtle
      gold: '#8A4F00', // status.warning
      goldLight: '#FBEFD8', // status.warningSubtle
      bg: '#F1F4FC', // bg.canvas
      card: '#FFFFFF', // bg.surface
    });
  });

  it('only produces valid hex colours for every brand key', () => {
    for (const value of Object.values(theme.colors.brand)) {
      expect(value).toMatch(HEX_COLOR);
    }
  });

  it('includes the Zyndio font family and border radius scale', () => {
    expect(theme.fontFamily.sans[0]).toBe('Inter');
    expect(theme.borderRadius.button).toBe('999px');
  });
});

describe('tailwind.config (TC-032: build-time Tailwind, was the CDN inline config)', () => {
  it('feeds the primary brand colour and the rest of the token theme into Tailwind', async () => {
    const { default: config } = await import('../../tailwind.config');
    const extend: any = config.theme?.extend;

    expect(extend.colors.brand.blue).toBe('#2C5CF2');
    expect(extend).toMatchObject(buildTailwindTheme());
    expect(extend.boxShadow).toEqual({
      soft: '0 4px 20px -2px rgba(0, 0, 0, 0.05)',
      glow: '0 0 15px rgba(139, 92, 246, 0.3)',
    });
    expect(config.darkMode).toEqual(['variant', '&:is(.dark *):not(.light *)']);
  });

  it('compiles brand utilities, the dark variant and the runtime accent classes into real CSS', async () => {
    const { default: config } = await import('../../tailwind.config');
    const postcss = (await import('postcss')).default;
    const tailwind = (await import('tailwindcss')).default;
    const result = await postcss([
      tailwind({
        ...config,
        content: [{ raw: '<div class="bg-brand-blue dark:bg-slate-900 shadow-soft rounded-button"></div>' }],
      } as any),
    ]).process('@tailwind utilities;', { from: undefined });
    const css = result.css.replace(/\s+/g, ' ');

    expect(css).toContain('.bg-brand-blue');
    expect(css.toLowerCase()).toContain('rgb(44 92 242');
    expect(css).toContain(':is(.dark *):not(.light *)');
    expect(css).toContain('.shadow-soft');
    expect(css).toContain('border-radius: 999px');
    // Safelisted: built from `bg-${color}-100` / `text-${color}-600` at runtime.
    for (const c of ['amber', 'blue', 'emerald', 'green', 'indigo', 'orange', 'purple', 'red', 'rose']) {
      expect(css).toContain(`.bg-${c}-100`);
      expect(css).toContain(`.text-${c}-600`);
    }
  });
});
