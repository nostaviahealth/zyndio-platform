// TC-021 item 18: the local/CI edge runtime must not run in "oneshot" mode.
//
// Root cause of the rare empty-body 503s from Edge Functions in CI (e.g. the
// reactivate-user 503 in run 40865054033): with `[edge_runtime] policy =
// "oneshot"` the user worker is terminated the moment it finishes its
// response. Terminating it cancels the worker's runtime token, which (in
// edge-runtime's net ops) also cancels the inbound connection token, and
// when that lands before the main server has handed the response back, the
// server replaces the finished response with `503`, empty body,
// `x-served-by: base/server` and logs `connection aborted (uri: ...)`.
// A/B under the same request stress (3 x 2,100 requests per policy): oneshot
// 5 such 503s, per_worker 0. "per_worker" keeps the worker for the next
// request (as the hosted platform does), so the race cannot happen;
// `supabase functions serve` still restarts on file changes.
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, it, expect } from 'vitest';

function edgeRuntimeSection(toml: string): string {
  const m = toml.match(/^\[edge_runtime\]\s*$([\s\S]*?)(?=^\[|(?![\s\S]))/m);
  if (!m) throw new Error('supabase/config.toml has no [edge_runtime] section');
  return m[1];
}

describe('supabase/config.toml [edge_runtime] (TC-021 item 18)', () => {
  const section = edgeRuntimeSection(readFileSync(resolve(__dirname, '../../supabase/config.toml'), 'utf8'));

  it('is enabled', () => {
    expect(section).toMatch(/^enabled\s*=\s*true\s*$/m);
  });

  it('uses policy = "per_worker", never "oneshot" (connection-aborted 503 race)', () => {
    const policy = section.match(/^policy\s*=\s*"([^"]*)"\s*$/m)?.[1];
    expect(policy).toBe('per_worker');
  });
});
