import React, { useCallback, useEffect, useState } from 'react';
import { Plus } from 'lucide-react';
import {
  API_SCOPES,
  ApiClient,
  ApiScope,
  DeliveryAttempt,
  DeliveryStatus,
  Environment,
  WEBHOOK_EVENT_TYPES,
  WebhookDelivery,
  WebhookEndpoint,
  WebhookEventType,
  createApiClient,
  createWebhookEndpoint,
  disableWebhookEndpoint,
  integrationErrorMessage,
  listApiClients,
  listDeliveries,
  listDeliveryAttempts,
  listWebhookEndpoints,
  revokeApiClient,
  rotateWebhookSecret,
} from '../../lib/integrationsApi';
import PageHeader from '../../components/ui/PageHeader';
import DataTable, { DataTableColumn } from '../../components/ui/DataTable';
import Dialog from '../../components/ui/Dialog';
import { useToast } from '../../components/ui/Toast';
import Button from '../../components/admin-auth/Button';
import SelectField from '../../components/ui/SelectField';
import TextInput from '../../components/ui/TextInput';
import FictionalDataTag from '../../components/ui/FictionalDataTag';

// PP-03 (minimum): org admins manage the zyndio.com server integration -
// OAuth API clients (secret shown once), webhook endpoints (secret shown once
// on create / rotate) and the webhook delivery log. Every change is an
// integration_admin_* RPC (org_admin + aal2 + own org, audited).

const SCOPE_LABELS: Record<ApiScope, string> = {
  'patients:write': 'Enrol and update patients',
  'patients:read': 'Read patients and summaries',
  'webhooks:manage': 'Manage webhook endpoints',
};

const ENV_LABELS: Record<Environment, string> = { sandbox: 'Sandbox', production: 'Production' };

const DELIVERY_STATUS_LABELS: Record<DeliveryStatus, string> = {
  pending: 'Retrying',
  succeeded: 'Delivered',
  dead_letter: 'Failed (dead letter)',
  cancelled: 'Cancelled',
};

const DELIVERY_STATUS_CLASSES: Record<DeliveryStatus, string> = {
  succeeded: 'bg-emerald-100 text-emerald-800 dark:bg-[#0F2A1D] dark:text-[#5FD39A]',
  pending: 'bg-[#E8EDFD] text-[#2C5CF2] dark:bg-[#18224A] dark:text-[#AFC3FF]',
  dead_letter: 'bg-red-50 text-[#B42318] dark:bg-[#2A1215] dark:text-[#FF8F86]',
  cancelled: 'bg-slate-100 text-slate-600 dark:bg-[#0B0F19] dark:text-[#A6B0C3]',
};

const CARD = 'mt-4 overflow-hidden rounded-xl border border-slate-200 bg-white dark:border-[#222838] dark:bg-[#10141F]';
const MUTED = 'text-sm text-slate-600 dark:text-[#A6B0C3]';
const LABEL = 'block text-sm font-semibold text-[#030616] dark:text-[#EEF1F8]';

function formatDateTime(value: string | null): string {
  if (!value) return '—';
  return new Date(value).toLocaleString();
}

function Pill({ className, children }: { className: string; children: React.ReactNode }) {
  return (
    <span className={`inline-flex items-center whitespace-nowrap rounded-full px-2.5 py-1 text-xs font-semibold ${className}`}>
      {children}
    </span>
  );
}

function EnvPill({ env }: { env: Environment }) {
  return (
    <Pill
      className={
        env === 'production'
          ? 'bg-amber-50 text-amber-800 dark:bg-[#2F220D] dark:text-[#F2B65A]'
          : 'bg-slate-100 text-slate-700 dark:bg-[#0B0F19] dark:text-[#A6B0C3]'
      }
    >
      {ENV_LABELS[env]}
    </Pill>
  );
}

function SectionHeader({ title, description, action }: { title: string; description: string; action?: React.ReactNode }) {
  return (
    <div className="flex flex-wrap items-end justify-between gap-3">
      <div>
        <h2 className="text-lg font-bold text-[#030616] dark:text-[#EEF1F8]">{title}</h2>
        <p className={`mt-1 max-w-2xl ${MUTED}`}>{description}</p>
      </div>
      {action}
    </div>
  );
}

function EnvironmentChoice({ value, onChange, name }: { value: Environment; onChange: (e: Environment) => void; name: string }) {
  return (
    <fieldset className="mt-4">
      <legend className={LABEL}>Environment</legend>
      <div className="mt-2 flex gap-6">
        {(['sandbox', 'production'] as Environment[]).map((env) => (
          <label key={env} className="flex min-h-[44px] items-center gap-2 text-sm text-[#030616] dark:text-[#EEF1F8]">
            <input type="radio" name={name} value={env} checked={value === env} onChange={() => onChange(env)} />
            {ENV_LABELS[env]}
          </label>
        ))}
      </div>
    </fieldset>
  );
}

// Shown exactly once, right after create / rotate. The value lives only in
// this component's props; closing the dialog drops it.
function SecretOnceDialog({
  title,
  label,
  identifierLabel,
  identifier,
  secret,
  onDone,
}: {
  title: string;
  label: string;
  identifierLabel: string;
  identifier: string;
  secret: string;
  onDone: () => void;
}) {
  const [copied, setCopied] = useState(false);
  const copy = async () => {
    try {
      await navigator.clipboard.writeText(secret);
      setCopied(true);
    } catch {
      setCopied(false);
    }
  };
  return (
    <Dialog titleId="secret-once-title" descriptionId="secret-once-desc" title={title} onClose={onDone} panelClassName="max-w-[600px]">
      <p id="secret-once-desc" className={`mt-2 ${MUTED}`}>
        Copy the {label.toLowerCase()} now and store it in your secrets manager. This is the only time it is shown; if it is
        lost, rotate or create a new one.
      </p>
      <dl className="mt-4 space-y-3">
        <div>
          <dt className={LABEL}>{identifierLabel}</dt>
          <dd className="mt-1 break-all font-mono text-sm text-[#030616] dark:text-[#EEF1F8]">{identifier}</dd>
        </div>
        <div>
          <dt className={LABEL}>{label}</dt>
          <dd className="mt-1 break-all rounded-md bg-slate-50 p-3 font-mono text-sm text-[#030616] dark:bg-[#0B0F19] dark:text-[#EEF1F8]" data-testid="secret-value">
            {secret}
          </dd>
        </div>
      </dl>
      <div className="mt-6 flex justify-end gap-3">
        <Button variant="outline" onClick={copy}>
          {copied ? 'Copied' : 'Copy secret'}
        </Button>
        <Button onClick={onDone} data-autofocus>
          I&apos;ve stored it
        </Button>
      </div>
    </Dialog>
  );
}

function ConfirmDialog({
  title,
  body,
  confirmLabel,
  busy,
  error,
  onConfirm,
  onCancel,
}: {
  title: string;
  body: string;
  confirmLabel: string;
  busy: boolean;
  error: string | null;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  return (
    <Dialog titleId="confirm-title" descriptionId="confirm-desc" title={title} onClose={onCancel}>
      <p id="confirm-desc" className={`mt-2 ${MUTED}`}>
        {body}
      </p>
      {error && (
        <p role="alert" className="mt-3 text-sm text-[#B42318] dark:text-[#FF8F86]">
          {error}
        </p>
      )}
      <div className="mt-6 flex justify-end gap-3">
        <Button variant="outline" onClick={onCancel} disabled={busy} data-autofocus>
          Cancel
        </Button>
        <Button variant="destructive" onClick={onConfirm} busy={busy}>
          {confirmLabel}
        </Button>
      </div>
    </Dialog>
  );
}

function NewClientDialog({ onCreated, onCancel }: { onCreated: (c: { client_id: string; client_secret: string }) => void; onCancel: () => void }) {
  const [name, setName] = useState('');
  const [environment, setEnvironment] = useState<Environment>('sandbox');
  const [scopes, setScopes] = useState<ApiScope[]>(['patients:write', 'patients:read', 'webhooks:manage']);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return setError('Enter a name, for example "zyndio.com backend".');
    if (scopes.length === 0) return setError('Choose at least one permission.');
    setBusy(true);
    setError(null);
    const result = await createApiClient(name.trim(), environment, scopes);
    setBusy(false);
    if (!result.ok) return setError(integrationErrorMessage(result.error));
    onCreated(result.value);
  };

  return (
    <Dialog titleId="new-client-title" title="New API client" onClose={onCancel} panelClassName="max-w-[600px]">
      <form onSubmit={submit} noValidate>
        <label htmlFor="client-name" className={`mt-4 ${LABEL}`}>
          Name
        </label>
        <TextInput id="client-name" className="mt-1" value={name} maxLength={100} onChange={(e) => setName(e.target.value)} data-autofocus />
        <EnvironmentChoice value={environment} onChange={setEnvironment} name="client-environment" />
        <fieldset className="mt-4">
          <legend className={LABEL}>Permissions</legend>
          {API_SCOPES.map((scope) => (
            <label key={scope} className="mt-2 flex min-h-[44px] items-center gap-2 text-sm text-[#030616] dark:text-[#EEF1F8]">
              <input
                type="checkbox"
                checked={scopes.includes(scope)}
                onChange={(e) => setScopes((prev) => (e.target.checked ? [...prev, scope] : prev.filter((s) => s !== scope)))}
              />
              {SCOPE_LABELS[scope]} <span className="font-mono text-xs text-slate-500 dark:text-[#A6B0C3]">{scope}</span>
            </label>
          ))}
        </fieldset>
        {error && (
          <p role="alert" className="mt-3 text-sm text-[#B42318] dark:text-[#FF8F86]">
            {error}
          </p>
        )}
        <div className="mt-6 flex justify-end gap-3">
          <Button type="button" variant="outline" onClick={onCancel} disabled={busy}>
            Cancel
          </Button>
          <Button type="submit" busy={busy} busyLabel="Creating…">
            Create client
          </Button>
        </div>
      </form>
    </Dialog>
  );
}

function NewEndpointDialog({ onCreated, onCancel }: { onCreated: (e: { id: string; secret: string }) => void; onCancel: () => void }) {
  const [url, setUrl] = useState('');
  const [description, setDescription] = useState('');
  const [environment, setEnvironment] = useState<Environment>('sandbox');
  const [events, setEvents] = useState<WebhookEventType[]>([...WEBHOOK_EVENT_TYPES]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!url.trim()) return setError(integrationErrorMessage('invalid_url'));
    if (events.length === 0) return setError(integrationErrorMessage('invalid_event_types'));
    setBusy(true);
    setError(null);
    const result = await createWebhookEndpoint(environment, url, description, events);
    setBusy(false);
    if (!result.ok) return setError(integrationErrorMessage(result.error));
    onCreated(result.value);
  };

  return (
    <Dialog titleId="new-endpoint-title" title="Add webhook endpoint" onClose={onCancel} panelClassName="max-w-[600px]">
      <form onSubmit={submit} noValidate>
        <label htmlFor="endpoint-url" className={`mt-4 ${LABEL}`}>
          Endpoint URL
        </label>
        <TextInput
          id="endpoint-url"
          className="mt-1"
          type="url"
          placeholder="https://hooks.example.com/zyndio"
          value={url}
          maxLength={2048}
          onChange={(e) => setUrl(e.target.value)}
          data-autofocus
        />
        <label htmlFor="endpoint-description" className={`mt-4 ${LABEL}`}>
          Description (optional)
        </label>
        <TextInput
          id="endpoint-description"
          className="mt-1"
          value={description}
          maxLength={200}
          onChange={(e) => setDescription(e.target.value)}
        />
        <EnvironmentChoice value={environment} onChange={setEnvironment} name="endpoint-environment" />
        <fieldset className="mt-4">
          <legend className={LABEL}>Events</legend>
          {WEBHOOK_EVENT_TYPES.map((type) => (
            <label key={type} className="mt-2 flex min-h-[44px] items-center gap-2 font-mono text-sm text-[#030616] dark:text-[#EEF1F8]">
              <input
                type="checkbox"
                checked={events.includes(type)}
                onChange={(e) => setEvents((prev) => (e.target.checked ? [...prev, type] : prev.filter((t) => t !== type)))}
              />
              {type}
            </label>
          ))}
        </fieldset>
        {error && (
          <p role="alert" className="mt-3 text-sm text-[#B42318] dark:text-[#FF8F86]">
            {error}
          </p>
        )}
        <div className="mt-6 flex justify-end gap-3">
          <Button type="button" variant="outline" onClick={onCancel} disabled={busy}>
            Cancel
          </Button>
          <Button type="submit" busy={busy} busyLabel="Saving…">
            Save endpoint
          </Button>
        </div>
      </form>
    </Dialog>
  );
}

function AttemptsDialog({ delivery, onClose }: { delivery: WebhookDelivery; onClose: () => void }) {
  const [attempts, setAttempts] = useState<DeliveryAttempt[] | null>(null);
  const [failed, setFailed] = useState(false);
  useEffect(() => {
    listDeliveryAttempts(delivery.id)
      .then(setAttempts)
      .catch(() => setFailed(true));
  }, [delivery.id]);

  const columns: DataTableColumn<DeliveryAttempt>[] = [
    { key: 'n', header: '#', render: (a) => a.attempt_number },
    { key: 'at', header: 'Sent', render: (a) => formatDateTime(a.attempted_at) },
    { key: 'status', header: 'Response', render: (a) => a.response_status ?? a.error ?? '—' },
    { key: 'ms', header: 'Time', render: (a) => `${a.duration_ms} ms` },
    { key: 'outcome', header: 'Outcome', render: (a) => a.outcome.replace('_', ' ') },
    {
      key: 'sha',
      header: 'Payload SHA-256',
      render: (a) => (
        <span className="font-mono text-xs" title={a.payload_sha256}>
          {a.payload_sha256.slice(0, 12)}…
        </span>
      ),
    },
  ];

  return (
    <Dialog titleId="attempts-title" title={`Attempts for ${delivery.event?.public_id ?? 'event'}`} onClose={onClose} panelClassName="max-w-[760px]">
      <p className={`mt-2 ${MUTED}`}>{delivery.endpoint?.url}</p>
      <div className="mt-4">
        {failed && <p className={MUTED}>We couldn&apos;t load the attempts. Try again.</p>}
        {!failed && attempts === null && <p role="status" className={MUTED}>Loading attempts…</p>}
        {!failed && attempts !== null && attempts.length === 0 && <p className={MUTED}>No attempts yet.</p>}
        {!failed && attempts !== null && attempts.length > 0 && (
          <DataTable columns={columns} rows={attempts} getRowId={(a) => String(a.id)} caption="Delivery attempts" />
        )}
      </div>
      <div className="mt-6 flex justify-end">
        <Button variant="outline" onClick={onClose} data-autofocus>
          Close
        </Button>
      </div>
    </Dialog>
  );
}

type DialogState =
  | { kind: 'none' }
  | { kind: 'new-client' }
  | { kind: 'new-endpoint' }
  | { kind: 'client-secret'; clientId: string; secret: string }
  | { kind: 'endpoint-secret'; endpointId: string; secret: string }
  | { kind: 'revoke-client'; client: ApiClient }
  | { kind: 'rotate-endpoint'; endpoint: WebhookEndpoint }
  | { kind: 'disable-endpoint'; endpoint: WebhookEndpoint }
  | { kind: 'attempts'; delivery: WebhookDelivery };

const IntegrationsPage: React.FC = () => {
  const { showToast } = useToast();
  const [clients, setClients] = useState<ApiClient[] | null>(null);
  const [endpoints, setEndpoints] = useState<WebhookEndpoint[] | null>(null);
  const [deliveries, setDeliveries] = useState<WebhookDelivery[] | null>(null);
  const [deliveryFilter, setDeliveryFilter] = useState<DeliveryStatus | 'all'>('all');
  const [loadError, setLoadError] = useState(false);
  const [dialog, setDialog] = useState<DialogState>({ kind: 'none' });
  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoadError(false);
    try {
      const [c, e] = await Promise.all([listApiClients(), listWebhookEndpoints()]);
      setClients(c);
      setEndpoints(e);
    } catch {
      setLoadError(true);
    }
  }, []);

  const loadDeliveries = useCallback(async () => {
    try {
      setDeliveries(await listDeliveries(deliveryFilter));
    } catch {
      setLoadError(true);
    }
  }, [deliveryFilter]);

  useEffect(() => {
    load();
  }, [load]);
  useEffect(() => {
    loadDeliveries();
  }, [loadDeliveries]);

  const closeDialog = () => {
    setDialog({ kind: 'none' });
    setActionError(null);
    setBusy(false);
  };

  const runAction = async (
    action: () => Promise<{ ok: true; value: unknown } | { ok: false; error: string }>,
    onSuccess: (value: unknown) => void
  ) => {
    setBusy(true);
    setActionError(null);
    const result = await action();
    setBusy(false);
    if (!result.ok) {
      setActionError(integrationErrorMessage(result.error));
      return;
    }
    onSuccess(result.value);
    load();
  };

  const clientColumns: DataTableColumn<ApiClient>[] = [
    { key: 'name', header: 'Name', render: (c) => <span className="font-semibold">{c.name}</span> },
    { key: 'env', header: 'Environment', render: (c) => <EnvPill env={c.environment} /> },
    { key: 'client_id', header: 'Client ID', render: (c) => <span className="font-mono text-xs">{c.client_id}</span> },
    { key: 'secret', header: 'Secret', render: (c) => <span className="font-mono text-xs">••••{c.secret_hint}</span> },
    { key: 'scopes', header: 'Permissions', render: (c) => <span className="font-mono text-xs">{c.scopes.join(' ')}</span> },
    { key: 'last_used', header: 'Last token', render: (c) => formatDateTime(c.last_used_at) },
    {
      key: 'status',
      header: 'Status',
      render: (c) =>
        c.revoked_at ? (
          <Pill className={DELIVERY_STATUS_CLASSES.cancelled}>Revoked</Pill>
        ) : (
          <Pill className={DELIVERY_STATUS_CLASSES.succeeded}>Active</Pill>
        ),
    },
    {
      key: 'actions',
      header: 'Actions',
      stickyRight: true,
      render: (c) =>
        c.revoked_at ? null : (
          <Button variant="secondary" className="px-3" onClick={() => setDialog({ kind: 'revoke-client', client: c })} aria-label={`Revoke ${c.name}`}>
            Revoke
          </Button>
        ),
    },
  ];

  const endpointColumns: DataTableColumn<WebhookEndpoint>[] = [
    {
      key: 'url',
      header: 'URL',
      render: (e) => (
        <div className="min-w-0">
          <p className="break-all font-mono text-xs">{e.url}</p>
          {e.description && <p className="mt-1 text-xs text-slate-500 dark:text-[#A6B0C3]">{e.description}</p>}
        </div>
      ),
    },
    { key: 'env', header: 'Environment', render: (e) => <EnvPill env={e.environment} /> },
    { key: 'events', header: 'Events', render: (e) => <span className="font-mono text-xs">{e.event_types.join(', ')}</span> },
    { key: 'rotated', header: 'Secret rotated', render: (e) => formatDateTime(e.secret_rotated_at) },
    {
      key: 'status',
      header: 'Status',
      render: (e) =>
        e.disabled_at ? (
          <Pill className={DELIVERY_STATUS_CLASSES.cancelled}>Disabled</Pill>
        ) : (
          <Pill className={DELIVERY_STATUS_CLASSES.succeeded}>Enabled</Pill>
        ),
    },
    {
      key: 'actions',
      header: 'Actions',
      stickyRight: true,
      render: (e) =>
        e.disabled_at ? null : (
          <div className="flex gap-1">
            <Button variant="secondary" className="px-3" onClick={() => setDialog({ kind: 'rotate-endpoint', endpoint: e })} aria-label={`Rotate secret for ${e.url}`}>
              Rotate secret
            </Button>
            <Button variant="secondary" className="px-3" onClick={() => setDialog({ kind: 'disable-endpoint', endpoint: e })} aria-label={`Disable ${e.url}`}>
              Disable
            </Button>
          </div>
        ),
    },
  ];

  const deliveryColumns: DataTableColumn<WebhookDelivery>[] = [
    { key: 'created', header: 'Created', render: (d) => formatDateTime(d.created_at) },
    {
      key: 'event',
      header: 'Event',
      render: (d) => (
        <div>
          <p className="font-mono text-xs">{d.event?.event_type}</p>
          <p className="font-mono text-xs text-slate-500 dark:text-[#A6B0C3]">{d.event?.public_id}</p>
        </div>
      ),
    },
    { key: 'endpoint', header: 'Endpoint', render: (d) => <span className="break-all font-mono text-xs">{d.endpoint?.url}</span> },
    { key: 'status', header: 'Status', render: (d) => <Pill className={DELIVERY_STATUS_CLASSES[d.status]}>{DELIVERY_STATUS_LABELS[d.status]}</Pill> },
    { key: 'attempts', header: 'Attempts', render: (d) => d.attempt_count },
    { key: 'last', header: 'Last response', render: (d) => d.last_response_status ?? d.last_error ?? '—' },
    {
      key: 'next',
      header: 'Next try',
      render: (d) => (d.status === 'pending' ? formatDateTime(d.next_attempt_at) : '—'),
    },
    {
      key: 'actions',
      header: 'Actions',
      stickyRight: true,
      render: (d) => (
        <Button variant="secondary" className="px-3" onClick={() => setDialog({ kind: 'attempts', delivery: d })} aria-label={`View attempts for ${d.event?.public_id ?? 'event'}`}>
          View attempts
        </Button>
      ),
    },
  ];

  return (
    <div className="relative">
      {typeof __PREVIEW_BUILD__ !== 'undefined' && __PREVIEW_BUILD__ && <FictionalDataTag />}
      <PageHeader
        title="Integrations"
        description="Credentials and webhooks for the zyndio.com server integration. Sandbox and production are kept separate."
      />

      {loadError && (
        <div className="mt-8 rounded-xl border border-slate-200 bg-white p-8 text-center dark:border-[#222838] dark:bg-[#10141F]">
          <p className={MUTED}>We couldn&apos;t load the integration settings. Check your connection and try again. No changes were made.</p>
          <Button
            className="mt-4"
            variant="outline"
            onClick={() => {
              load();
              loadDeliveries();
            }}
          >
            Try again
          </Button>
        </div>
      )}

      <section className="mt-8" aria-labelledby="api-clients-heading">
        <SectionHeader
          title="API clients"
          description="OAuth client credentials the zyndio.com backend uses to call the platform API. Access tokens last 15 minutes."
          action={
            <Button onClick={() => setDialog({ kind: 'new-client' })}>
              <Plus className="h-4 w-4" aria-hidden="true" />
              New API client
            </Button>
          }
        />
        <span id="api-clients-heading" className="sr-only">
          API clients
        </span>
        {clients === null && !loadError && <p role="status" className={`mt-4 ${MUTED}`}>Loading API clients…</p>}
        {clients !== null && clients.length === 0 && <p className={`mt-4 ${MUTED}`}>No API clients yet.</p>}
        {clients !== null && clients.length > 0 && (
          <div className={CARD}>
            <DataTable columns={clientColumns} rows={clients} getRowId={(c) => c.id} caption="API clients" />
          </div>
        )}
      </section>

      <section className="mt-10" aria-label="Webhook endpoints">
        <SectionHeader
          title="Webhook endpoints"
          description="Where the platform sends patient.enrolled, patient.activated, patient.deactivated and consent.updated events. Each delivery is signed with the endpoint's secret."
          action={
            <Button onClick={() => setDialog({ kind: 'new-endpoint' })}>
              <Plus className="h-4 w-4" aria-hidden="true" />
              Add endpoint
            </Button>
          }
        />
        {endpoints === null && !loadError && <p role="status" className={`mt-4 ${MUTED}`}>Loading endpoints…</p>}
        {endpoints !== null && endpoints.length === 0 && <p className={`mt-4 ${MUTED}`}>No webhook endpoints yet.</p>}
        {endpoints !== null && endpoints.length > 0 && (
          <div className={CARD}>
            <DataTable columns={endpointColumns} rows={endpoints} getRowId={(e) => e.id} caption="Webhook endpoints" />
          </div>
        )}
      </section>

      <section className="mt-10" aria-label="Delivery log">
        <SectionHeader
          title="Delivery log"
          description="The 50 most recent webhook deliveries. Failed deliveries are retried after 1 min, 5 min, 30 min, 2 h, 6 h, 12 h and 24 h, then moved to the dead letter."
          action={
            <SelectField
              aria-label="Filter deliveries by status"
              value={deliveryFilter}
              onChange={(e) => setDeliveryFilter(e.target.value as DeliveryStatus | 'all')}
            >
              <option value="all">Status: All</option>
              <option value="pending">Retrying</option>
              <option value="succeeded">Delivered</option>
              <option value="dead_letter">Failed (dead letter)</option>
              <option value="cancelled">Cancelled</option>
            </SelectField>
          }
        />
        {deliveries === null && !loadError && <p role="status" className={`mt-4 ${MUTED}`}>Loading deliveries…</p>}
        {deliveries !== null && deliveries.length === 0 && <p className={`mt-4 ${MUTED}`}>No deliveries to show.</p>}
        {deliveries !== null && deliveries.length > 0 && (
          <div className={CARD}>
            <DataTable columns={deliveryColumns} rows={deliveries} getRowId={(d) => d.id} caption="Webhook deliveries" />
          </div>
        )}
      </section>

      {dialog.kind === 'new-client' && (
        <NewClientDialog
          onCancel={closeDialog}
          onCreated={(c) => {
            setDialog({ kind: 'client-secret', clientId: c.client_id, secret: c.client_secret });
            load();
          }}
        />
      )}
      {dialog.kind === 'client-secret' && (
        <SecretOnceDialog
          title="API client created"
          label="Client secret"
          identifierLabel="Client ID"
          identifier={dialog.clientId}
          secret={dialog.secret}
          onDone={closeDialog}
        />
      )}
      {dialog.kind === 'new-endpoint' && (
        <NewEndpointDialog
          onCancel={closeDialog}
          onCreated={(e) => {
            setDialog({ kind: 'endpoint-secret', endpointId: e.id, secret: e.secret });
            load();
          }}
        />
      )}
      {dialog.kind === 'endpoint-secret' && (
        <SecretOnceDialog
          title="Signing secret"
          label="Signing secret"
          identifierLabel="Endpoint ID"
          identifier={dialog.endpointId}
          secret={dialog.secret}
          onDone={closeDialog}
        />
      )}
      {dialog.kind === 'revoke-client' && (
        <ConfirmDialog
          title={`Revoke ${dialog.client.name}?`}
          body="Its access tokens stop working immediately and it can't get new ones. This can't be undone; create a new client to restore access."
          confirmLabel="Revoke client"
          busy={busy}
          error={actionError}
          onCancel={closeDialog}
          onConfirm={() =>
            runAction(
              () => revokeApiClient(dialog.client.id),
              () => {
                closeDialog();
                showToast({ message: `${dialog.client.name} revoked.` });
              }
            )
          }
        />
      )}
      {dialog.kind === 'rotate-endpoint' && (
        <ConfirmDialog
          title="Rotate signing secret?"
          body="A new secret is issued now. The old one keeps signing deliveries for 24 hours so the receiver can switch over."
          confirmLabel="Rotate secret"
          busy={busy}
          error={actionError}
          onCancel={closeDialog}
          onConfirm={() =>
            runAction(
              () => rotateWebhookSecret(dialog.endpoint.id),
              (value) => {
                const v = value as { id: string; secret: string };
                setActionError(null);
                setDialog({ kind: 'endpoint-secret', endpointId: v.id, secret: v.secret });
              }
            )
          }
        />
      )}
      {dialog.kind === 'disable-endpoint' && (
        <ConfirmDialog
          title="Disable this endpoint?"
          body="No more events are sent to it and deliveries still waiting to retry are cancelled. The delivery history is kept."
          confirmLabel="Disable endpoint"
          busy={busy}
          error={actionError}
          onCancel={closeDialog}
          onConfirm={() =>
            runAction(
              () => disableWebhookEndpoint(dialog.endpoint.id),
              () => {
                closeDialog();
                showToast({ message: 'Endpoint disabled.' });
                loadDeliveries();
              }
            )
          }
        />
      )}
      {dialog.kind === 'attempts' && <AttemptsDialog delivery={dialog.delivery} onClose={closeDialog} />}
    </div>
  );
};

export default IntegrationsPage;
