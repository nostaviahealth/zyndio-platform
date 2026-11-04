import { supabase } from './supabase';

// PP-03: the org admin's Integrations page. Reads go straight to the tables
// under RLS (org_admin + aal2 + own org, column grants that never include a
// secret, hash or event payload - 20261104150000); every change goes through
// an integration_admin_* RPC that re-checks the same rule server side and
// writes an audit row (20261104150100). Secrets come back exactly once, from
// the create / rotate call, and are never stored client side.

export type Environment = 'sandbox' | 'production';
export type ApiScope = 'patients:write' | 'patients:read' | 'webhooks:manage';
export type WebhookEventType = 'patient.enrolled' | 'patient.activated' | 'patient.deactivated' | 'consent.updated';
export type DeliveryStatus = 'pending' | 'succeeded' | 'dead_letter' | 'cancelled';

export const API_SCOPES: ApiScope[] = ['patients:write', 'patients:read', 'webhooks:manage'];
export const WEBHOOK_EVENT_TYPES: WebhookEventType[] = [
  'patient.enrolled',
  'patient.activated',
  'patient.deactivated',
  'consent.updated',
];

export interface ApiClient {
  id: string;
  name: string;
  environment: Environment;
  client_id: string;
  secret_hint: string;
  scopes: ApiScope[];
  created_at: string;
  last_used_at: string | null;
  revoked_at: string | null;
}

export interface CreatedApiClient {
  id: string;
  name: string;
  environment: Environment;
  client_id: string;
  client_secret: string;
  scopes: ApiScope[];
}

export interface WebhookEndpoint {
  id: string;
  public_id: string;
  environment: Environment;
  url: string;
  description: string | null;
  event_types: WebhookEventType[];
  created_at: string;
  secret_rotated_at: string | null;
  disabled_at: string | null;
}

export interface EndpointWithSecret {
  id: string; // public id (whe_...)
  url: string;
  secret: string;
}

export interface WebhookDelivery {
  id: string;
  status: DeliveryStatus;
  attempt_count: number;
  next_attempt_at: string;
  last_response_status: number | null;
  last_error: string | null;
  created_at: string;
  completed_at: string | null;
  event: { public_id: string; event_type: WebhookEventType; environment: Environment } | null;
  endpoint: { public_id: string; url: string } | null;
}

export interface DeliveryAttempt {
  id: number;
  attempt_number: number;
  attempted_at: string;
  payload_sha256: string;
  response_status: number | null;
  duration_ms: number;
  error: string | null;
  outcome: 'succeeded' | 'retry_scheduled' | 'dead_letter';
}

export type ApiResult<T> = { ok: true; value: T } | { ok: false; error: string };

// Maps the {"error": "..."} codes the endpoint RPCs return, and Postgres
// errors (42501 / PT404 / 22023), to a short message the page can show.
const ERROR_MESSAGES: Record<string, string> = {
  invalid_url: 'Enter a full URL, for example https://hooks.example.com/zyndio.',
  https_required: 'The URL must start with https://.',
  url_not_allowed: 'Use a public hostname. IP addresses, localhost and internal names are not allowed.',
  invalid_event_types: 'Choose at least one event.',
  invalid_request: 'Check the details and try again.',
  endpoint_limit_reached: 'This environment already has 10 endpoints. Disable one first.',
  not_found: 'This item no longer exists. Refresh the page.',
  forbidden: 'You need to be an admin signed in with two-factor to do this.',
  internal_error: "Something went wrong. Nothing was changed. Try again.",
};

export function integrationErrorMessage(code: string): string {
  return ERROR_MESSAGES[code] ?? ERROR_MESSAGES.internal_error;
}

function rpcErrorCode(error: { code?: string } | null): string {
  if (!error) return 'internal_error';
  if (error.code === '42501') return 'forbidden';
  if (error.code === 'PT404') return 'not_found';
  if (error.code === '22023') return 'invalid_request';
  return 'internal_error';
}

async function callRpc<T>(fn: string, args: Record<string, unknown>): Promise<ApiResult<T>> {
  const { data, error } = await supabase.rpc(fn, args);
  if (error) return { ok: false, error: rpcErrorCode(error) };
  const code = (data as { error?: string } | null)?.error;
  if (code) return { ok: false, error: code };
  return { ok: true, value: data as T };
}

export async function listApiClients(): Promise<ApiClient[]> {
  const { data, error } = await supabase
    .from('api_clients')
    .select('id, name, environment, client_id, secret_hint, scopes, created_at, last_used_at, revoked_at')
    .order('created_at', { ascending: false });
  if (error) throw error;
  return (data ?? []) as ApiClient[];
}

export function createApiClient(name: string, environment: Environment, scopes: ApiScope[]) {
  return callRpc<CreatedApiClient>('integration_admin_create_api_client', {
    p_name: name,
    p_environment: environment,
    p_scopes: scopes,
  });
}

export function revokeApiClient(id: string) {
  return callRpc<null>('integration_admin_revoke_api_client', { p_id: id });
}

export async function listWebhookEndpoints(): Promise<WebhookEndpoint[]> {
  const { data, error } = await supabase
    .from('webhook_endpoints')
    .select('id, public_id, environment, url, description, event_types, created_at, secret_rotated_at, disabled_at')
    .order('created_at', { ascending: false });
  if (error) throw error;
  return (data ?? []) as WebhookEndpoint[];
}

export function createWebhookEndpoint(
  environment: Environment,
  url: string,
  description: string,
  eventTypes: WebhookEventType[]
) {
  return callRpc<EndpointWithSecret>('integration_admin_create_webhook_endpoint', {
    p_environment: environment,
    p_url: url.trim(),
    p_description: description.trim() || null,
    p_event_types: eventTypes,
  });
}

export function rotateWebhookSecret(id: string) {
  return callRpc<EndpointWithSecret>('integration_admin_rotate_webhook_secret', { p_id: id });
}

export function disableWebhookEndpoint(id: string) {
  return callRpc<unknown>('integration_admin_disable_webhook_endpoint', { p_id: id });
}

export const DELIVERY_PAGE_SIZE = 50;

export async function listDeliveries(status: DeliveryStatus | 'all'): Promise<WebhookDelivery[]> {
  let query = supabase
    .from('webhook_deliveries')
    .select(
      'id, status, attempt_count, next_attempt_at, last_response_status, last_error, created_at, completed_at, ' +
        'event:webhook_events(public_id, event_type, environment), endpoint:webhook_endpoints(public_id, url)'
    )
    .order('created_at', { ascending: false })
    .limit(DELIVERY_PAGE_SIZE);
  if (status !== 'all') query = query.eq('status', status);
  const { data, error } = await query;
  if (error) throw error;
  return (data ?? []) as unknown as WebhookDelivery[];
}

export async function listDeliveryAttempts(deliveryId: string): Promise<DeliveryAttempt[]> {
  const { data, error } = await supabase
    .from('webhook_delivery_attempts')
    .select('id, attempt_number, attempted_at, payload_sha256, response_status, duration_ms, error, outcome')
    .eq('delivery_id', deliveryId)
    .order('attempt_number', { ascending: true });
  if (error) throw error;
  return (data ?? []) as DeliveryAttempt[];
}
