import React from 'react';
import PageHeader from '../../components/ui/PageHeader';
import DataTable, { DataTableColumn } from '../../components/ui/DataTable';
import Dialog from '../../components/ui/Dialog';
import Button from '../../components/admin-auth/Button';
import RowActionsMenu, { RowActionItem } from '../../components/ui/RowActionsMenu';
import StatusBadge from '../../components/ui/StatusBadge';
import TwoFactorStatus from '../../components/ui/TwoFactorStatus';
import NameCell from '../../components/ui/NameCell';
import SearchField from '../../components/ui/SearchField';
import SelectField from '../../components/ui/SelectField';
import { Plus } from 'lucide-react';
import { ROLE_LABELS, roleDescriptionsFor } from '../admin/UsersRoles';
import { PreviewMember, PREVIEW_MEMBERS, SELF_USER_ID } from './previewFixtures';

function renderStatusBadge(member: PreviewMember, daysLeft = 7) {
  if (member.status === 'invited') return <StatusBadge kind="invited">Invited · {daysLeft} days left</StatusBadge>;
  if (member.status === 'deactivated') return <StatusBadge kind="deactivated">Deactivated</StatusBadge>;
  return <StatusBadge kind="active">Active</StatusBadge>;
}

const Legend: React.FC<{ isPlatformAdmin?: boolean }> = ({ isPlatformAdmin = false }) => (
  <section className="mt-10 rounded-xl border border-slate-200 bg-white p-6 dark:border-[#222838] dark:bg-[#10141F]">
    <div className="flex flex-wrap items-center gap-3">
      <h2 className="text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-[#A6B0C3]">What each role can do</h2>
      <span className="rounded-full border border-amber-200 bg-amber-50 px-2.5 py-1 text-xs font-semibold text-amber-800 dark:border-[#F2B65A]/40 dark:bg-[#2F220D] dark:text-[#F2B65A]">
        Draft, to confirm with Zyndio
      </span>
    </div>
    <dl className="mt-4 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
      {(['physician', 'care_coordinator', 'org_admin', 'read_only'] as const).map((role) => (
        <div key={role}>
          <dt className="font-semibold text-[#030616] dark:text-[#EEF1F8]">{ROLE_LABELS[role]}</dt>
          <dd className="text-sm text-slate-600 dark:text-[#A6B0C3]">{roleDescriptionsFor(isPlatformAdmin)[role]}</dd>
        </div>
      ))}
    </dl>
  </section>
);

const Toastish: React.FC<{ message: string; action?: string }> = ({ message, action }) => (
  <div
    role="status"
    className="fixed bottom-6 left-1/2 z-50 flex -translate-x-1/2 items-center gap-3 rounded-full bg-[#030616] px-5 py-3 text-sm text-white shadow-lg"
  >
    <svg
      aria-hidden="true"
      width="20"
      height="20"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2.2"
      strokeLinecap="round"
      strokeLinejoin="round"
      className="shrink-0"
    >
      <path d="M5 12.5l4.5 4.5L19 7.5" />
    </svg>
    <span>{message}</span>
    {action && <span className="font-semibold text-[#8FB0FF] underline-offset-2">{action}</span>}
  </div>
);

const ASSIGNABLE_ROLES = ['physician', 'care_coordinator', 'org_admin', 'read_only'] as const;

const Table: React.FC<{ members: PreviewMember[]; isPlatformAdmin?: boolean }> = ({ members, isPlatformAdmin = false }) => {
  const resetActionLabel = isPlatformAdmin ? 'Reset two-factor' : 'Request two-factor reset';
  const columns: DataTableColumn<PreviewMember>[] = [
    { key: 'name', header: 'Name', render: (m) => <NameCell name={m.name} email={m.email} /> },
    {
      key: 'role',
      header: 'Role',
      render: (m) => {
        const isSelf = m.user_id === SELF_USER_ID;
        if (m.status === 'deactivated' || isSelf) {
          return <span className="text-[#030616] dark:text-[#EEF1F8]">{ROLE_LABELS[m.role]}</span>;
        }
        return (
          <SelectField
            aria-label={`Change role for ${m.email}`}
            wrapperClassName="w-full"
            value={m.role}
            onChange={() => {}}
          >
            {ASSIGNABLE_ROLES.map((r) => (
              <option key={r} value={r}>
                {ROLE_LABELS[r]}
              </option>
            ))}
          </SelectField>
        );
      },
    },
    { key: 'twofactor', header: 'Two-factor', render: (m) => <TwoFactorStatus value={m.twoFactor} /> },
    { key: 'lastsignin', header: 'Last sign-in', render: (m) => m.lastSignIn },
    { key: 'status', header: 'Status', render: (m) => renderStatusBadge(m) },
    {
      key: 'actions',
      header: '',
      render: (m) => {
        const isSelf = m.user_id === SELF_USER_ID;
        if (isSelf) {
          return <div aria-label={`More actions for ${m.email} (you)`} />;
        }
        const items: RowActionItem[] =
          m.status === 'deactivated'
            ? [{ label: 'Reactivate', onClick: () => {} }]
            : [
                { label: resetActionLabel, onClick: () => {} },
                { label: 'Deactivate', destructive: true, onClick: () => {} },
              ];
        return <RowActionsMenu email={m.email} items={items} />;
      },
    },
  ];
  return (
    <div className="mt-2 overflow-x-auto rounded-xl border border-slate-200 bg-white dark:border-[#222838] dark:bg-[#10141F]">
      <DataTable columns={columns} rows={members} getRowId={(m) => m.user_id} caption="Users and roles" />
    </div>
  );
};

const Header: React.FC = () => (
  <PageHeader
    title="Users and roles"
    description="People at Zyndio who can sign in to the care portal. Everyone must use two-factor sign-in."
    actions={
      <Button>
        <Plus className="h-4 w-4" aria-hidden="true" />
        Invite user
      </Button>
    }
  />
);

const Toolbar: React.FC<{ count: number }> = ({ count }) => (
  <>
    <div className="mt-6 flex flex-wrap items-center gap-3">
      <SearchField aria-label="Search by name or email" placeholder="Search by name or email" className="flex-1" readOnly />
      <SelectField aria-label="Filter by status" value="all" onChange={() => {}}>
        <option value="all">Status: All</option>
      </SelectField>
    </div>
    <p className="mt-3 text-sm text-slate-500 dark:text-[#A6B0C3]">{count} people</p>
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
        <div className="mt-8 text-sm text-slate-500 dark:text-[#A6B0C3]" role="status">
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
        <div className="mt-8 rounded-xl border border-slate-200 bg-white p-8 text-center dark:border-[#222838] dark:bg-[#10141F]">
          <p className="font-semibold text-[#030616] dark:text-[#EEF1F8]">You&apos;re the only user so far</p>
          <p className="mt-2 text-sm text-slate-600 dark:text-[#A6B0C3]">
            Invite your physicians and care team. Each person sets their own password and two-factor sign-in from
            the invite link.
          </p>
          <Button className="mt-4">
            <Plus className="h-4 w-4" aria-hidden="true" />
            Invite user
          </Button>
        </div>
      </div>
    );
  }

  if (state === 'error') {
    return (
      <div>
        <Header />
        <div className="mt-8 rounded-xl border border-slate-200 bg-white p-8 text-center dark:border-[#222838] dark:bg-[#10141F]">
          <p className="text-sm text-slate-600 dark:text-[#A6B0C3]">
            We couldn&apos;t load the user list. Check your connection and try again. No changes were made.
          </p>
          <Button className="mt-4" variant="outline">
            Try again
          </Button>
        </div>
      </div>
    );
  }

  // reset-2fa is the Zyndio-admin view (default MANIFEST states are
  // otherwise all the signed-in-as-org-admin view, matching copy-deck's
  // reset-2fa state which shows Taylor Brooks as a Zyndio admin).
  const isPlatformAdminView = state === 'reset-2fa';
  const base = (
    <div>
      <Header />
      <Toolbar count={PREVIEW_MEMBERS.length} />
      <Table members={PREVIEW_MEMBERS} isPlatformAdmin={isPlatformAdminView} />
      <Legend isPlatformAdmin={isPlatformAdminView} />
    </div>
  );

  if (state === 'invite-sent') return <>{base}<Toastish message="Invite sent to alex.lindgren@example.test." action="Undo" /></>;
  if (state === 'deactivated') return <>{base}<Toastish message="Riley Chen was deactivated and signed out." action="Undo" /></>;
  if (state === 'reset-requested') {
    return (
      <>
        {base}
        <Toastish message="Reset requested for Dr. Priya Raman. A Zyndio admin will confirm it's really them first." />
      </>
    );
  }

  if (state === 'invite' || state === 'invite-validation') {
    return (
      <>
        {base}
        <Dialog titleId="invite-title" title="Invite a user" onClose={() => {}} initialFocusSelector="#preview-invite-email">
          <p className="mt-2 text-sm text-slate-600 dark:text-[#A6B0C3]">
            They&apos;ll get an email with a link to set a password and two-factor sign-in. The link works for 7 days.
          </p>
          <div className="mt-4 space-y-4">
            <div>
              <label htmlFor="preview-invite-email" className="text-sm font-semibold text-[#030616] dark:text-[#EEF1F8]">
                Work email
              </label>
              <input
                id="preview-invite-email"
                readOnly
                defaultValue="alex.lindgren@example.test"
                className="mt-1 min-h-[44px] w-full rounded-md border border-slate-300 bg-white px-3 text-sm text-[#030616] dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8]"
              />
              {state === 'invite-validation' && (
                <p className="mt-1 text-sm text-red-600 dark:text-[#FF8F86]" role="alert">
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
          <p className="mt-2 text-sm text-slate-600 dark:text-[#A6B0C3]">
            From {ROLE_LABELS[target.role]} to {ROLE_LABELS.care_coordinator}. Riley will be able to edit patient
            records, work the review queue and enter treatment details.
          </p>
          <p className="mt-2 text-sm text-slate-600 dark:text-[#A6B0C3]">
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
          <p className="mt-2 text-sm text-slate-600 dark:text-[#A6B0C3]">
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
          <p className="mt-2 text-sm text-slate-600 dark:text-[#A6B0C3]">
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
        <Dialog titleId="reset-2fa-title" title={`Reset two-factor sign-in for ${priya.name}?`} onClose={() => {}}>
          <div className="mt-4 flex gap-2 rounded-xl border border-amber-200 bg-amber-50 p-3 text-sm text-amber-800 dark:border-[#F2B65A]/40 dark:bg-[#2F220D] dark:text-[#F2B65A]">
            <span aria-hidden="true">⚠️</span>
            <p>
              Only do this after you&apos;ve confirmed it&apos;s really {priya.name}, for example on a video call.
              Never because of an email alone.
            </p>
          </div>
          <p className="mt-4 text-sm text-slate-600 dark:text-[#A6B0C3]">
            {priya.name}&apos;s authenticator app and recovery codes will stop working, and {priya.name} is signed
            out on every device. At next sign-in, they&apos;ll set up two-factor sign-in again. The reset is
            recorded in the audit log.
          </p>
          <p className="mt-2 text-sm text-slate-500 dark:text-[#A6B0C3]">Only Zyndio admins can reset two-factor sign-in.</p>
          <div className="mt-6 flex justify-end gap-3">
            <Button type="button" variant="outline">
              Cancel
            </Button>
            <Button type="button" variant="destructive">
              Reset two-factor
            </Button>
          </div>
        </Dialog>
      </>
    );
  }

  if (state === 'request-2fa-reset') {
    return (
      <>
        {base}
        <Dialog titleId="request-2fa-reset-title" title={`Ask for a two-factor reset for ${priya.name}?`} onClose={() => {}}>
          <p className="mt-2 text-sm text-slate-600 dark:text-[#A6B0C3]">
            Only a Zyndio admin can reset two-factor sign-in. They&apos;ll confirm it&apos;s really{' '}
            {priya.name} before they reset it, then {priya.name} is signed out on every device and sets it up
            again at next sign-in.
          </p>
          <div className="mt-4">
            <label htmlFor="preview-request-2fa-reset-reason" className="text-sm font-semibold text-[#030616] dark:text-[#EEF1F8]">
              Reason (optional)
            </label>
            <textarea
              id="preview-request-2fa-reset-reason"
              readOnly
              maxLength={500}
              defaultValue="Priya got a new phone and can't open the authenticator app."
              className="mt-1 min-h-[88px] w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm text-[#030616] placeholder:text-slate-400 dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8] dark:placeholder:text-[#8F9AAF]"
            />
            <p className="mt-1 text-xs text-slate-500 dark:text-[#A6B0C3]">
              Zyndio admins see this with your name and time. Do not include patient details.
            </p>
          </div>
          <div className="mt-6 flex justify-end gap-3">
            <Button type="button" variant="outline">
              Cancel
            </Button>
            <Button type="button">Send request</Button>
          </div>
        </Dialog>
      </>
    );
  }

  return base;
};

export default PreviewUsersRoles;
