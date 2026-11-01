// TC-018 item 1 round 2 (Clara, PR #24 review): the existing invite-dialog
// field-error test mocks inviteUser() directly, so it never sees what the
// real supabase-js client returns for a non-2xx Edge Function response -
// `{ data: null, error: FunctionsHttpError }`, where the error body (the
// field name) is never read. Against the real server this showed the
// generic "check your connection" banner instead of the inline field error
// (hands-on/real-server400-mapping.txt). Mock at the supabase client level
// with a real FunctionsHttpError wrapping a real Response, the same shape
// supabase-js itself throws (see node_modules/@supabase/functions-js
// FunctionsClient.js), so this test exercises the real inviteUser().
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { FunctionsHttpError, FunctionsFetchError } from '@supabase/supabase-js';

const invoke = vi.fn();

vi.mock('./supabase', () => ({
  supabase: {
    functions: { invoke: (...args: unknown[]) => invoke(...args) },
  },
}));

import { inviteUser } from './usersRolesApi';

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

describe('inviteUser() against a real FunctionsHttpError (TC-018 item 1 round 2)', () => {
  beforeEach(() => {
    invoke.mockReset();
  });

  it('maps a real 400 {error:"invalid_request", field:"email"} response to the inline field error', async () => {
    invoke.mockResolvedValueOnce({
      data: null,
      error: new FunctionsHttpError(jsonResponse({ error: 'invalid_request', field: 'email' }, 400)),
    });
    const result = await inviteUser('qa24real@localhost', 'physician', 'Alex Lindgren');
    expect(result).toEqual({ ok: false, error: 'invalid_request', field: 'email' });
  });

  it('maps a real 400 {error:"invalid_request", field:"full_name"} response the same way', async () => {
    invoke.mockResolvedValueOnce({
      data: null,
      error: new FunctionsHttpError(jsonResponse({ error: 'invalid_request', field: 'full_name' }, 400)),
    });
    const result = await inviteUser('alex@example.test', 'physician', '');
    expect(result).toEqual({ ok: false, error: 'invalid_request', field: 'full_name' });
  });

  it('maps a real 403 {error:"role_not_allowed"} response (no field) without a field key', async () => {
    invoke.mockResolvedValueOnce({
      data: null,
      error: new FunctionsHttpError(jsonResponse({ error: 'role_not_allowed' }, 403)),
    });
    const result = await inviteUser('alex@example.test', 'org_admin', 'Alex Lindgren');
    expect(result).toEqual({ ok: false, error: 'role_not_allowed', field: undefined });
  });

  it('falls back to internal_error on a non-JSON error body (e.g. a gateway HTML error page)', async () => {
    invoke.mockResolvedValueOnce({
      data: null,
      error: new FunctionsHttpError(
        new Response('<html>502 Bad Gateway</html>', { status: 502, headers: { 'Content-Type': 'text/html' } })
      ),
    });
    const result = await inviteUser('alex@example.test', 'physician', 'Alex Lindgren');
    expect(result).toEqual({ ok: false, error: 'internal_error' });
  });

  it('stays internal_error for a network failure with no response to read', async () => {
    invoke.mockResolvedValueOnce({ data: null, error: new FunctionsFetchError({ message: 'network down' }) });
    const result = await inviteUser('alex@example.test', 'physician', 'Alex Lindgren');
    expect(result).toEqual({ ok: false, error: 'internal_error' });
  });
});
