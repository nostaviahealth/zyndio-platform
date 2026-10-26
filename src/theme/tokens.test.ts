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

describe('vite transformIndexHtml plugin', () => {
  it('injects the primary brand colour into the built index.html', async () => {
    const { default: viteConfig } = await import('../../vite.config');
    const config = typeof viteConfig === 'function'
      ? await viteConfig({ mode: 'production', command: 'build' })
      : viteConfig;
    const plugin: any = config.plugins
      .flat()
      .find((p: any) => p && p.name === 'zyndio-brand-theme');

    expect(plugin).toBeTruthy();

    const html = await plugin.transformIndexHtml(
      '<script>tailwind.config = { theme: { extend: Object.assign({}, /*ZYNDIO_BRAND_THEME*/{}) } }</script>'
    );

    expect(html).toContain('#2C5CF2');
  });
});
