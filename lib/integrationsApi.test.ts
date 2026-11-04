// PP-03: integrationsApi maps RPC outcomes - Postgres errors (42501 / PT404 /
// 22023) and the {"error": "..."} payloads of the endpoint RPCs - to stable
// codes, and reads only non-secret columns. Mocked at the supabase client.
import { describe, it, expect, vi, beforeEach } from 'vitest';

const rpc = vi.fn();
const selects: string[] = [];

vi.mock('./supabase', () => ({
  supabase: {
    rpc: (...args: unknown[]) => rpc(...args),
    from: () => {
      const builder = {
        select: (cols: string) => {
          selects.push(cols);
          return builder;
        },
        order: () => builder,
        limit: () => builder,
        eq: () => builder,
        then: (resolve: (v: unknown) => unknown) => resolve({ data: [], error: null }),
      };
      return builder;
    },
  },
}));

import {
  createApiClient,
  createWebhookEndpoint,
  integrationErrorMessage,
  listApiClients,
  listDeliveries,
  listWebhookEndpoints,
  revokeApiClient,
} from './integrationsApi';

describe('integrationsApi (PP-03)', () => {
  beforeEach(() => {
    rpc.mockReset();
    selects.length = 0;
  });

  it('returns the created client, secret included, on success', async () => {
    rpc.mockResolvedValueOnce({ data: { client_id: 'zyc_test_x', client_secret: 'zys_x' }, error: null });
    const result = await createApiClient('Fictional', 'sandbox', ['patients:read']);
    expect(rpc).toHaveBeenCalledWith('integration_admin_create_api_client', {
      p_name: 'Fictional',
      p_environment: 'sandbox',
      p_scopes: ['patients:read'],
    });
    expect(result).toEqual({ ok: true, value: { client_id: 'zyc_test_x', client_secret: 'zys_x' } });
  });

  it('maps 42501 to forbidden and PT404 to not_found', async () => {
    rpc.mockResolvedValueOnce({ data: null, error: { code: '42501', message: 'not authorized' } });
    expect(await createApiClient('x', 'sandbox', ['patients:read'])).toEqual({ ok: false, error: 'forbidden' });
    rpc.mockResolvedValueOnce({ data: null, error: { code: 'PT404', message: 'nope' } });
    expect(await revokeApiClient('id')).toEqual({ ok: false, error: 'not_found' });
  });

  it('passes through the endpoint RPC error payloads and trims input', async () => {
    rpc.mockResolvedValueOnce({ data: { error: 'https_required' }, error: null });
    expect(await createWebhookEndpoint('production', '  http://hooks.example.test  ', '  ', ['consent.updated'])).toEqual({
      ok: false,
      error: 'https_required',
    });
    expect(rpc.mock.calls[0][1]).toEqual({
      p_environment: 'production',
      p_url: 'http://hooks.example.test',
      p_description: null,
      p_event_types: ['consent.updated'],
    });
    expect(integrationErrorMessage('https_required')).toMatch(/https:\/\//);
    expect(integrationErrorMessage('something_new')).toMatch(/Nothing was changed/);
  });

  it('never selects a secret, hash or payload column', async () => {
    await listApiClients();
    await listWebhookEndpoints();
    await listDeliveries('all');
    const all = selects.join(' ');
    expect(all).not.toMatch(/secret_hash|\bsecret\b|previous_secret|\bdata\b/);
    expect(all).toContain('secret_hint');
  });
});
