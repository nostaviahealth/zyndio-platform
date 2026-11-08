// @vitest-environment jsdom
// PP-03: Integrations page - API clients (secret shown once), webhook
// endpoints (secret shown once on create / rotate) and the delivery log.
// Fictional data only.
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

const CLIENTS = [
  {
    id: 'c1',
    name: 'Fictional sandbox backend',
    environment: 'sandbox',
    client_id: 'zyc_test_aaaaaaaaaaaaaaaaaaaaaaaa',
    secret_hint: 'f00d',
    scopes: ['patients:read', 'patients:write'],
    created_at: '2026-11-01T10:00:00Z',
    last_used_at: null,
    revoked_at: null,
  },
];

const ENDPOINTS = [
  {
    id: 'e1',
    public_id: 'whe_000000000000000000000001',
    environment: 'production',
    url: 'https://hooks.example.test/zyndio',
    description: 'Fictional receiver',
    event_types: ['patient.enrolled', 'consent.updated'],
    created_at: '2026-11-01T10:00:00Z',
    secret_rotated_at: null,
    disabled_at: null,
  },
];

const DELIVERIES = [
  {
    id: 'd1',
    status: 'dead_letter',
    attempt_count: 8,
    next_attempt_at: '2026-11-02T10:00:00Z',
    last_response_status: 500,
    last_error: 'http_500',
    created_at: '2026-11-01T10:00:00Z',
    completed_at: '2026-11-02T10:00:00Z',
    event: { public_id: 'evt_000000000000000000000001', event_type: 'patient.enrolled', environment: 'production' },
    endpoint: { public_id: 'whe_000000000000000000000001', url: 'https://hooks.example.test/zyndio' },
  },
];

const ATTEMPTS = [
  {
    id: 1,
    attempt_number: 1,
    attempted_at: '2026-11-01T10:00:01Z',
    payload_sha256: 'ab'.repeat(32),
    response_status: 500,
    duration_ms: 120,
    error: 'http_500',
    outcome: 'retry_scheduled',
  },
];

const api = vi.hoisted(() => ({
  listApiClients: vi.fn(),
  listWebhookEndpoints: vi.fn(),
  listDeliveries: vi.fn(),
  listDeliveryAttempts: vi.fn(),
  createApiClient: vi.fn(),
  revokeApiClient: vi.fn(),
  createWebhookEndpoint: vi.fn(),
  rotateWebhookSecret: vi.fn(),
  disableWebhookEndpoint: vi.fn(),
}));

vi.mock('../../lib/integrationsApi', async (importOriginal) => {
  const actual = await importOriginal<typeof import('../../lib/integrationsApi')>();
  return { ...actual, ...api };
});
vi.mock('../../lib/supabase', () => ({ supabase: {} }));

import IntegrationsPage from '../../pages/admin/Integrations';
import { ToastProvider } from '../../components/ui/Toast';

function renderPage() {
  return render(
    <ToastProvider>
      <IntegrationsPage />
    </ToastProvider>
  );
}

const CLIENT_SECRET = `zys_${'1'.repeat(64)}`;
const SIGNING_SECRET = `whsec_${'2'.repeat(48)}`;

describe('IntegrationsPage (PP-03)', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    api.listApiClients.mockResolvedValue(CLIENTS);
    api.listWebhookEndpoints.mockResolvedValue(ENDPOINTS);
    api.listDeliveries.mockResolvedValue(DELIVERIES);
    api.listDeliveryAttempts.mockResolvedValue(ATTEMPTS);
  });

  it('lists clients, endpoints and deliveries without any secret, only the hint', async () => {
    renderPage();
    const clients = await screen.findByRole('table', { name: 'API clients' });
    expect(within(clients).getByText('Fictional sandbox backend')).toBeInTheDocument();
    expect(within(clients).getByText('••••f00d')).toBeInTheDocument();
    const endpoints = await screen.findByRole('table', { name: 'Webhook endpoints' });
    expect(within(endpoints).getByText('https://hooks.example.test/zyndio')).toBeInTheDocument();
    const deliveries = await screen.findByRole('table', { name: 'Webhook deliveries' });
    expect(within(deliveries).getByText('Failed (dead letter)')).toBeInTheDocument();
    expect(within(deliveries).getByText('500')).toBeInTheDocument();
    expect(document.body.textContent).not.toMatch(/whsec_|zys_/);
  });

  it('creating a client shows the secret once; after closing it is gone', async () => {
    api.createApiClient.mockResolvedValue({
      ok: true,
      value: { id: 'c2', name: 'Fictional live', environment: 'production', client_id: 'zyc_live_bbbbbbbbbbbbbbbbbbbbbbbb', client_secret: CLIENT_SECRET, scopes: ['patients:read'] },
    });
    const user = userEvent.setup();
    renderPage();
    await screen.findByRole('table', { name: 'API clients' });
    await user.click(screen.getByRole('button', { name: /New API client/ }));
    await user.type(screen.getByLabelText('Name'), 'Fictional live');
    await user.click(screen.getByLabelText('Production'));
    await user.click(screen.getByRole('checkbox', { name: /Enrol and update patients/ }));
    await user.click(screen.getByRole('checkbox', { name: /Manage webhook endpoints/ }));
    await user.click(screen.getByRole('button', { name: 'Create client' }));

    expect(api.createApiClient).toHaveBeenCalledWith('Fictional live', 'production', ['patients:read']);
    expect(await screen.findByTestId('secret-value')).toHaveTextContent(CLIENT_SECRET);
    expect(screen.getByText('zyc_live_bbbbbbbbbbbbbbbbbbbbbbbb')).toBeInTheDocument();
    expect(api.listApiClients).toHaveBeenCalledTimes(2);

    await user.click(screen.getByRole('button', { name: /I've stored it/ }));
    expect(screen.queryByTestId('secret-value')).not.toBeInTheDocument();
    expect(document.body.textContent).not.toContain(CLIENT_SECRET);
  });

  it('refuses a client with no permissions before calling the server', async () => {
    const user = userEvent.setup();
    renderPage();
    await screen.findByRole('table', { name: 'API clients' });
    await user.click(screen.getByRole('button', { name: /New API client/ }));
    await user.type(screen.getByLabelText('Name'), 'Fictional');
    for (const name of [/Enrol and update/, /Read patients/, /Manage webhook/]) {
      await user.click(screen.getByRole('checkbox', { name }));
    }
    await user.click(screen.getByRole('button', { name: 'Create client' }));
    expect(screen.getByRole('alert')).toHaveTextContent('Choose at least one permission.');
    expect(api.createApiClient).not.toHaveBeenCalled();
  });

  it('revoking a client asks for confirmation, then calls the RPC', async () => {
    api.revokeApiClient.mockResolvedValue({ ok: true, value: null });
    const user = userEvent.setup();
    renderPage();
    await user.click(await screen.findByRole('button', { name: 'Revoke Fictional sandbox backend' }));
    expect(api.revokeApiClient).not.toHaveBeenCalled();
    await user.click(screen.getByRole('button', { name: 'Revoke client' }));
    expect(api.revokeApiClient).toHaveBeenCalledWith('c1');
    await waitFor(() => expect(screen.getByRole('status')).toHaveTextContent('Fictional sandbox backend revoked.'));
  });

  it('a refused endpoint URL shows the server reason inline', async () => {
    api.createWebhookEndpoint.mockResolvedValue({ ok: false, error: 'url_not_allowed' });
    const user = userEvent.setup();
    renderPage();
    await screen.findByRole('table', { name: 'Webhook endpoints' });
    await user.click(screen.getByRole('button', { name: /Add endpoint/ }));
    await user.type(screen.getByLabelText('Endpoint URL'), 'https://10.0.0.1/hook');
    await user.click(screen.getByRole('button', { name: 'Save endpoint' }));
    expect(api.createWebhookEndpoint).toHaveBeenCalledWith('sandbox', 'https://10.0.0.1/hook', '', [
      'patient.enrolled',
      'patient.activated',
      'patient.deactivated',
      'consent.updated',
    ]);
    expect(screen.getByRole('alert')).toHaveTextContent(/public hostname/);
  });

  it('a new endpoint shows its signing secret once', async () => {
    api.createWebhookEndpoint.mockResolvedValue({
      ok: true,
      value: { id: 'whe_000000000000000000000002', url: 'https://hooks.example.test/new', secret: SIGNING_SECRET },
    });
    const user = userEvent.setup();
    renderPage();
    await screen.findByRole('table', { name: 'Webhook endpoints' });
    await user.click(screen.getByRole('button', { name: /Add endpoint/ }));
    await user.type(screen.getByLabelText('Endpoint URL'), 'https://hooks.example.test/new');
    await user.click(screen.getByRole('button', { name: 'Save endpoint' }));
    expect(await screen.findByTestId('secret-value')).toHaveTextContent(SIGNING_SECRET);
    await user.click(screen.getByRole('button', { name: /I've stored it/ }));
    expect(document.body.textContent).not.toContain(SIGNING_SECRET);
  });

  it('rotating a secret confirms first and then reveals the new secret once', async () => {
    api.rotateWebhookSecret.mockResolvedValue({
      ok: true,
      value: { id: 'whe_000000000000000000000001', url: 'https://hooks.example.test/zyndio', secret: SIGNING_SECRET },
    });
    const user = userEvent.setup();
    renderPage();
    await user.click(await screen.findByRole('button', { name: 'Rotate secret for https://hooks.example.test/zyndio' }));
    expect(screen.getByText(/old one keeps signing deliveries for 24 hours/)).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Rotate secret' }));
    expect(api.rotateWebhookSecret).toHaveBeenCalledWith('e1');
    expect(await screen.findByTestId('secret-value')).toHaveTextContent(SIGNING_SECRET);
  });

  it('disabling an endpoint surfaces a server refusal without closing', async () => {
    api.disableWebhookEndpoint.mockResolvedValue({ ok: false, error: 'forbidden' });
    const user = userEvent.setup();
    renderPage();
    await user.click(await screen.findByRole('button', { name: 'Disable https://hooks.example.test/zyndio' }));
    await user.click(screen.getByRole('button', { name: 'Disable endpoint' }));
    expect(screen.getByRole('alert')).toHaveTextContent(/two-factor/);
    expect(screen.getByRole('alertdialog')).toBeInTheDocument();
  });

  it('delivery log filters by status and shows each attempt', async () => {
    const user = userEvent.setup();
    renderPage();
    await screen.findByRole('table', { name: 'Webhook deliveries' });
    await user.selectOptions(screen.getByLabelText('Filter deliveries by status'), 'dead_letter');
    await waitFor(() => expect(api.listDeliveries).toHaveBeenLastCalledWith('dead_letter'));

    await user.click(screen.getByRole('button', { name: 'View attempts for evt_000000000000000000000001' }));
    expect(api.listDeliveryAttempts).toHaveBeenCalledWith('d1');
    const attempts = await screen.findByRole('table', { name: 'Delivery attempts' });
    expect(within(attempts).getByText('120 ms')).toBeInTheDocument();
    expect(within(attempts).getByText('retry scheduled')).toBeInTheDocument();
  });

  it('a load failure offers a retry and makes no changes', async () => {
    api.listApiClients.mockRejectedValueOnce(new Error('offline'));
    const user = userEvent.setup();
    renderPage();
    expect(await screen.findByText(/couldn.t load the integration settings/)).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await screen.findByRole('table', { name: 'API clients' })).toBeInTheDocument();
  });
});
