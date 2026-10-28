import { describe, it, expect } from 'vitest';
import { build } from 'vite';
import { readdirSync, readFileSync, mkdtempSync, rmSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { PREVIEW_FIXTURE_MARKER } from '../../pages/preview/previewFixtures';

// OVERRIDES #8: the preview/screenshot harness and its fixture data must
// never ship in the default production bundle. Builds the real app twice
// (default mode, then --mode preview) into throwaway dirs and greps the
// emitted JS for the fixture marker - proves the exclusion is driven by
// __PREVIEW_BUILD__ dead-code elimination, not an accident of what happens
// to be imported today.
function concatenatedBundle(outDir: string): string {
  const assetsDir = join(outDir, 'assets');
  return readdirSync(assetsDir)
    .filter((f) => f.endsWith('.js'))
    .map((f) => readFileSync(join(assetsDir, f), 'utf8'))
    .join('\n');
}

describe('preview harness is excluded from the default build', () => {
  it('default `vite build` bundle contains no preview fixture strings', async () => {
    const outDir = mkdtempSync(join(tmpdir(), 'zyndio-build-default-'));
    try {
      await build({ build: { outDir, emptyOutDir: true }, logLevel: 'silent' });
      const bundle = concatenatedBundle(outDir);
      expect(bundle).not.toContain(PREVIEW_FIXTURE_MARKER);
      expect(bundle).not.toContain('taylor.brooks@example.test');
      expect(bundle).not.toContain('/__preview');
    } finally {
      rmSync(outDir, { recursive: true, force: true });
    }
  }, 60_000);

  it('`vite build --mode preview` bundle does contain the harness (sanity check)', async () => {
    const outDir = mkdtempSync(join(tmpdir(), 'zyndio-build-preview-'));
    try {
      await build({ mode: 'preview', build: { outDir, emptyOutDir: true }, logLevel: 'silent' });
      const bundle = concatenatedBundle(outDir);
      expect(bundle).toContain(PREVIEW_FIXTURE_MARKER);
    } finally {
      rmSync(outDir, { recursive: true, force: true });
    }
  }, 60_000);
});
