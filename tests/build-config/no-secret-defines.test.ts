// Security: nothing secret may be inlined into the staff-portal browser bundle.
//
// vite.config.ts used to `define` process.env.API_KEY / process.env.GEMINI_API_KEY
// from GEMINI_API_KEY, so any build run with that variable set (as it is for
// the Edge Functions) shipped the Gemini key to every browser that loaded the
// admin app. Nothing in the web app reads it - the model is only called from
// the `intelligence` Edge Function - so the bundle must never carry it.
import { describe, it, expect, afterEach } from 'vitest';
import type { UserConfig } from 'vite';
import viteConfig from '../../vite.config';

const SENTINEL = 'sentinel-secret-must-not-reach-bundle';
const SECRET_VARS = [
  'GEMINI_API_KEY',
  'ELEVENLABS_API_KEY',
  'SUPABASE_SERVICE_ROLE_KEY',
  'SUPABASE_SERVICE_KEY',
  'REVENUECAT_WEBHOOK_AUTH',
];

function resolveConfig(mode: string): UserConfig {
  const factory = viteConfig as unknown as (env: { mode: string; command: string }) => UserConfig;
  return factory({ mode, command: 'build' });
}

describe('vite.config.ts', () => {
  const saved: Record<string, string | undefined> = {};

  afterEach(() => {
    for (const name of SECRET_VARS) {
      if (saved[name] === undefined) delete process.env[name];
      else process.env[name] = saved[name];
    }
  });

  for (const mode of ['production', 'preview', 'development']) {
    it(`inlines no server-side secret into the ${mode} bundle`, () => {
      for (const name of SECRET_VARS) {
        saved[name] = process.env[name];
        process.env[name] = `${SENTINEL}-${name}`;
      }
      const define = resolveConfig(mode).define ?? {};
      expect(JSON.stringify(define)).not.toContain(SENTINEL);
      for (const key of Object.keys(define)) {
        expect(key).not.toMatch(/API_KEY|SERVICE_(ROLE_)?KEY|SECRET|WEBHOOK_AUTH/);
      }
    });
  }
});
