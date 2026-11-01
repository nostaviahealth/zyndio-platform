// TC-018 item 1 round 2 (Clara, PR #24 review): createPatient() uses the same
// supabase.functions.invoke(...) -> { ok: false, error: 'internal_error' }
// pattern as inviteUser() did, so it has the same bug against a real server -
// a 400 with a field name collapses to the generic internal_error instead of
// the inline field error. Mock at the supabase client level with a real
// FunctionsHttpError wrapping a real Response (see usersRolesApi.test.ts).
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { FunctionsHttpError, FunctionsFetchError } from '@supabase/supabase-js';

const invoke = vi.fn();

vi.mock('./supabase', () => ({
  supabase: {
    functions: { invoke: (...args: unknown[]) => invoke(...args) },
  },
}));

import { createPatient } from './patientsApi';

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

describe('createPatient() against a real FunctionsHttpError (TC-018 item 1 round 2)', () => {
  beforeEach(() => {
    invoke.mockReset();
  });

  it('maps a real 400 {error:"invalid_request", field:"email"} response to the inline field error', async () => {
    invoke.mockResolvedValueOnce({
      data: null,
      error: new FunctionsHttpError(jsonResponse({ error: 'invalid_request', field: 'email' }, 400)),
    });
    const result = await createPatient('qa24real@localhost', 'Fictional Patient');
    expect(result).toEqual({ ok: false, error: 'invalid_request', field: 'email' });
  });

  it('falls back to internal_error on a non-JSON error body', async () => {
    invoke.mockResolvedValueOnce({
      data: null,
      error: new FunctionsHttpError(
        new Response('<html>502 Bad Gateway</html>', { status: 502, headers: { 'Content-Type': 'text/html' } })
      ),
    });
    const result = await createPatient('alex@example.test', 'Fictional Patient');
    expect(result).toEqual({ ok: false, error: 'internal_error' });
  });

  it('stays internal_error for a network failure with no response to read', async () => {
    invoke.mockResolvedValueOnce({ data: null, error: new FunctionsFetchError({ message: 'network down' }) });
    const result = await createPatient('alex@example.test', 'Fictional Patient');
    expect(result).toEqual({ ok: false, error: 'internal_error' });
  });
});
