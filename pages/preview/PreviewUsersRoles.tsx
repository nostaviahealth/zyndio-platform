import React from 'react';
import PageHeader from '../../components/ui/PageHeader';
import DataTable, { DataTableColumn } from '../../components/ui/DataTable';
import Dialog from '../../components/ui/Dialog';
import Button from '../../components/admin-auth/Button';
import { ROLE_LABELS, ROLE_DESCRIPTIONS } from '../admin/UsersRoles';
import { PreviewMember, PREVIEW_MEMBERS, SELF_USER_ID } from './previewFixtures';

const STATUS_LABELS: Record<string, string> = { invited: 'Invited', active: 'Active', deactivated: 'Deactivated' };

function row(member: PreviewMember, extraStatus?: string) {
  return member.status === 'invited' ? `${STATUS_LABELS[member.status]} · ${extraStatus ?? '7 days left'}` : STATUS_LABELS[member.status];
}

const Legend: React.FC = () => (
  <section className="mt-10 rounded-xl border border-slate-200 bg-white p-6">
    <h2 className="text-xs font-semibold uppercase tracking-wide text-slate-500">
      What each role can do <span className="normal-case text-slate-400">(Draft, to confirm with Zyndio)</span>
    </h2>
    <dl className="mt-4 grid gap-4 sm:grid-cols-2">
      {(['physician', 'care_coordinator', 'org_admin', 'read_only'] as const).map((role) => (
        <div key={role}>
          <dt className="font-semibold text-[#030616]">{ROLE_LABELS[role]}</dt>
          <dd className="text-sm text-slate-600">{ROLE_DESCRIPTIONS[role]}</dd>
        </div>
      ))}
    </dl>
  </section>
);

const Toastish: React.FC<{ message: string; action?: string }> = ({ message, action }) => (
  <div
    role="status"
    className="fixed bottom-6 left-1/2 z-50 flex -translate-x-1/2 items-center gap-4 rounded-full bg-[#030616] px-5 py-3 text-sm text-white shadow-lg"
  >
    <span>{message}</span>
    {action && <span className="font-semibold text-[#8FB0FF] underline-offset-2">{action}</span>}
  </div>
);

const Table: React.FC<{ members: PreviewMember[] }> = ({ members }) => {
  const columns: DataTableColumn<PreviewMember>[] = [
    { key: 'name', header: 'Name', render: (m) => m.name },
    { key: 'email', header: '', render: (m) => <span className="text-slate-500">{m.email}</span> },
    { key: 'role', header: 'Role', render: (m) => ROLE_LABELS[m.role] },
    { key: 'twofactor', header: 'Two-factor', render: (m) => m.twoFactor },
    { key: 'lastsignin', header: 'Last sign-in', render: (m) => m.lastSignIn },
    { key: 'status', header: 'Status', render: (m) => row(m) },
    {
      key: 'actions',
      header: 'Actions',
      render: (m) => (
        <div aria-label={`More actions for ${m.name}`} className="flex gap-2 text-xs font-semibold">
          {m.status === 'deactivated' ? (
            <span className="text-[#2C5CF2]">Reactivate</span>
          ) : (
            <>
              <span>{ROLE_LABELS[m.role]}</span>
              {m.user_id !== SELF_USER_ID && (
                <>
                  <span className="text-[#2C5CF2]">Request 2FA reset</span>
                  <span className="text-red-600">Deactivate</span>
                </>
              )}
            </>
          )}
        </div>
      ),
    },
  ];
  return (
    <div className="mt-2 overflow-x-auto rounded-xl border border-slate-200 bg-white">
      <DataTable columns={columns} rows={members} getRowId={(m) => m.user_id} caption="Users and roles" />
    </div>
  );
};

const Header: React.FC = () => (
  <PageHeader
    title="Users and roles"
    description="People at Zyndio who can sign in to the care portal. Everyone must use two-factor sign-in."
    actions={<Button>Invite user</Button>}
  />
);

const Toolbar: React.FC<{ count: number }> = ({ count }) => (
  <>
    <div className="mt-6 flex flex-wrap items-center gap-3">
      <input
        aria-label="Search by name or email"
        placeholder="Search by name or email"
        className="min-h-[44px] flex-1 rounded-full border border-slate-300 px-4 text-sm"
        readOnly
      />
      <select aria-label="Filter by status" className="min-h-[44px] rounded-full border border-slate-300 px-4 text-sm" readOnly>
        <option>Status: All</option>
      </select>
    </div>
    <p className="mt-3 text-sm text-slate-500">{count} people</p>
  </>
);

// 07-users-roles preview states (handoff README state list, low-codes n/a
// here - that drop only applies to 04-recovery-sign-in). Static/fixture-only
// rendering (no network calls) - see UsersRoles.tsx for the live page.
const PreviewUsersRoles: React.FC<{ state: string }> = ({ state }) => {
  const target = PREVIEW_MEMBERS.find((m) => m.user_id === 'preview-riley-chen')!;
  const priya = PREVIEW_MEMBERS.find((m) => m.user_id === 'preview-priya-raman')!;

  if (state === 'loading') {
    return (
      <div>
        <Header />
        <Toolbar count={PREVIEW_MEMBERS.length} />
        <div className="mt-8 text-sm text-slate-500" role="status">
          Loading users…
        </div>
      </div>
    );
  }

  if (state === 'empty') {
    return (
      <div>
        <Header />
        <Table members={[PREVIEW_MEMBERS[0]]} />
        <div className="mt-8 rounded-xl border border-slate-200 bg-white p-8 text-center">
          <p className="font-semibold text-[#030616]">You&apos;re the only user so far</p>
          <p className="mt-2 text-sm text-slate-600">
            Invite your physicians and care team. Each person sets their own password and two-factor sign-in from
            the invite link.
          </p>
          <Button className="mt-4">Invite user</Button>
        </div>
      </div>
    );
  }

  if (state === 'error') {
    return (
      <div>
        <Header />
        <div className="mt-8 rounded-xl border border-slate-200 bg-white p-8 text-center">
          <p className="text-sm text-slate-600">
            We couldn&apos;t load the user list. Check your connection and try again. No changes were made.
          </p>
          <Button className="mt-4" variant="outline">
            Try again
          </Button>
        </div>
      </div>
    );
  }

  const base = (
    <div>
      <Header />
      <Toolbar count={PREVIEW_MEMBERS.length} />
      <Table members={PREVIEW_MEMBERS} />
      <Legend />
    </div>
  );

  if (state === 'invite-sent') return <>{base}<Toastish message="Invite sent to alex.lindgren@example.test." action="Undo" /></>;
  if (state === 'deactivated') return <>{base}<Toastish message="Riley Chen was deactivated and signed out." action="Undo" /></>;

  if (state === 'invite' || state === 'invite-validation') {
    return (
      <>
        {base}
        <Dialog titleId="invite-title" title="Invite a user" onClose={() => {}} initialFocusSelector="#preview-invite-email">
          <p className="mt-2 text-sm text-slate-600">
            They&apos;ll get an email with a link to set a password and two-factor sign-in. The link works for 7 days.
          </p>
          <div className="mt-4 space-y-4">
            <div>
              <label htmlFor="preview-invite-email" className="text-sm font-semibold text-[#030616]">
                Work email
              </label>
              <input
                id="preview-invite-email"
                readOnly
                defaultValue="alex.lindgren@example.test"
                className="mt-1 min-h-[44px] w-full rounded-md border border-slate-300 px-3 text-sm"
              />
              {state === 'invite-validation' && (
                <p className="mt-1 text-sm text-red-600" role="alert">
                  Someone with this email already has an account.
                </p>
              )}
            </div>
            <div className="flex justify-end gap-3">
              <Button type="button" variant="outline">
                Cancel
              </Button>
              <Button type="button">Send invite</Button>
            </div>
          </div>
        </Dialog>
      </>
    );
  }

  if (state === 'role-confirm') {
    return (
      <>
        {base}
        <Dialog titleId="role-confirm-title" title={`Change ${target.name}'s role?`} onClose={() => {}}>
          <p className="mt-2 text-sm text-slate-600">
            From {ROLE_LABELS[target.role]} to {ROLE_LABELS.care_coordinator}. Riley will be able to edit patient
            records, work the review queue and enter treatment details.
          </p>
          <p className="mt-2 text-sm text-slate-600">
            The change applies the next time Riley loads a page, and it&apos;s recorded in the audit log.
          </p>
          <div className="mt-6 flex justify-end gap-3">
            <Button type="button" variant="outline">
              Cancel
            </Button>
            <Button type="button">Change role</Button>
          </div>
        </Dialog>
      </>
    );
  }

  if (state === 'deactivate-confirm') {
    return (
      <>
        {base}
        <Dialog titleId="deactivate-confirm-title" title={`Deactivate ${target.name}?`} onClose={() => {}}>
          <p className="mt-2 text-sm text-slate-600">
            Riley will be signed out everywhere and won&apos;t be able to sign in. Their past activity stays in the
            audit log. You can reactivate them later.
          </p>
          <div className="mt-6 flex justify-end gap-3">
            <Button type="button" variant="outline">
              Cancel
            </Button>
            <Button type="button" variant="destructive">
              Deactivate
            </Button>
          </div>
        </Dialog>
      </>
    );
  }

  if (state === 'last-admin') {
    return (
      <>
        {base}
        <Dialog titleId="last-admin-title" title="You can't deactivate the only Admin" onClose={() => {}}>
          <p className="mt-2 text-sm text-slate-600">
            Taylor Brooks is the only Admin, so the portal would have nobody to manage users. Make someone else an
            Admin first, then try again.
          </p>
          <div className="mt-6 flex justify-end">
            <Button type="button">OK</Button>
          </div>
        </Dialog>
      </>
    );
  }

  if (state === 'reset-2fa') {
    return (
      <>
        {base}
        <Dialog
          titleId="reset-2fa-title"
          title={`Ask a Zyndio admin to reset two-factor sign-in for ${priya.name}?`}
          onClose={() => {}}
        >
          <p className="mt-2 text-sm text-slate-600">
            A Zyndio admin will confirm it&apos;s really them (for example on a video call) before resetting. This
            request is recorded in the audit log.
          </p>
          <div className="mt-6 flex justify-end gap-3">
            <Button type="button" variant="outline">
              Cancel
            </Button>
            <Button type="button">Request reset</Button>
          </div>
        </Dialog>
      </>
    );
  }

  return base;
};

export default PreviewUsersRoles;
