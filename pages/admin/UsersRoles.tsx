import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { supabase } from '../../lib/supabase';
import {
  AppRole,
  MemberStatus,
  OrgMember,
  changeMemberRole,
  checkIsPlatformAdmin,
  deactivateUser,
  inviteUser,
  listOrgMembers,
  reactivateUser,
  requestMfaReset,
  resetMfa,
} from '../../lib/usersRolesApi';
import PageHeader from '../../components/ui/PageHeader';
import DataTable, { DataTableColumn } from '../../components/ui/DataTable';
import Dialog from '../../components/ui/Dialog';
import { useToast } from '../../components/ui/Toast';
import Button from '../../components/admin-auth/Button';
import RowActionsMenu, { RowActionItem } from '../../components/ui/RowActionsMenu';
import StatusBadge from '../../components/ui/StatusBadge';
import TwoFactorStatus from '../../components/ui/TwoFactorStatus';
import NameCell from '../../components/ui/NameCell';

export const ROLE_LABELS: Record<AppRole, string> = {
  org_admin: 'Admin',
  physician: 'Physician',
  care_coordinator: 'Care coordinator',
  read_only: 'Read-only',
};

// Henry's round-2 ruling (handoff README "Two-factor reset by role"): an
// org admin can only ask a Zyndio admin to reset someone's 2FA, never
// perform the reset itself - "resets two-factor sign-in" in the copy deck
// is stale against that ruling (already enforced server side, see
// supabase/functions/reset-mfa and request_mfa_reset()).
export const ROLE_DESCRIPTIONS: Record<AppRole, string> = {
  physician: 'Views and updates patient records, checks lab values, approves outcomes.',
  care_coordinator:
    "Views patients, works the review queue and patient questions, enters treatment details. Can't approve outcomes.",
  org_admin: 'Invites people, assigns roles, deactivates accounts, asks a Zyndio admin to reset two-factor sign-in.',
  read_only: "Views patient records. Can't change, approve or export anything.",
};

// A Zyndio (platform) admin actually performs the reset themselves, so their
// view of the legend reads differently for the Admin row (copy-deck
// "### reset-2fa": "...resets two-factor sign-in").
export function roleDescriptionsFor(isPlatformAdmin: boolean): Record<AppRole, string> {
  if (!isPlatformAdmin) return ROLE_DESCRIPTIONS;
  return { ...ROLE_DESCRIPTIONS, org_admin: 'Invites people, assigns roles, deactivates accounts, resets two-factor sign-in.' };
}

const ASSIGNABLE_ROLES: AppRole[] = ['physician', 'care_coordinator', 'org_admin', 'read_only'];

function formatLastSignIn(member: OrgMember): string {
  // list_org_members() doesn't surface auth.users.last_sign_in_at yet (would
  // need a service-role join beyond this step's scope) - invited members
  // have never signed in by definition; everyone else is "unknown" rather
  // than a fabricated date.
  return member.status === 'invited' ? 'Never' : 'Unknown';
}

// list_org_members() has no display-name column (auth.users is the source
// of truth for email only - see list_org_members()'s own comment). Derive a
// readable name from the local part of the email instead of adding one, the
// same stopgap this page already uses for last-sign-in/two-factor.
function displayNameFromEmail(email: string): string {
  const local = email.split('@')[0] ?? email;
  return local
    .split(/[._-]+/)
    .filter(Boolean)
    .map((part) => part[0].toUpperCase() + part.slice(1))
    .join(' ');
}

function formatTwoFactor(member: OrgMember): string {
  return member.status === 'invited' ? 'Not set up yet' : 'Unknown';
}

// Invite links are valid 7 days from org_members.created_at (invite time -
// see 20261026120000_tc005_schema.sql's `invites.expires_at` default). The
// RPC doesn't surface expires_at directly, so this derives the same window
// from the member row's own created_at rather than adding a column.
function invitedDaysLeft(member: OrgMember): number {
  const createdMs = new Date(member.created_at).getTime();
  const daysElapsed = Math.floor((Date.now() - createdMs) / (24 * 60 * 60 * 1000));
  return Math.max(0, 7 - daysElapsed);
}

function renderStatusBadge(member: OrgMember): React.ReactNode {
  if (member.status === 'invited') {
    return <StatusBadge kind="invited">Invited · {invitedDaysLeft(member)} days left</StatusBadge>;
  }
  if (member.status === 'deactivated') {
    return <StatusBadge kind="deactivated">Deactivated</StatusBadge>;
  }
  return <StatusBadge kind="active">Active</StatusBadge>;
}

type DialogState =
  | { kind: 'invite' }
  | { kind: 'role-confirm'; member: OrgMember; newRole: AppRole }
  | { kind: 'deactivate-confirm'; member: OrgMember }
  | { kind: 'last-admin' }
  // Zyndio (platform) admin only - performs the reset directly.
  | { kind: 'reset-2fa'; member: OrgMember }
  // Org admin - can only ask a Zyndio admin to reset it.
  | { kind: 'request-2fa-reset'; member: OrgMember }
  | null;

const UsersRolesPage: React.FC = () => {
  const { showToast } = useToast();
  const [members, setMembers] = useState<OrgMember[] | null>(null);
  const [loadError, setLoadError] = useState(false);
  const [selfUserId, setSelfUserId] = useState<string | null>(null);
  const [isPlatformAdmin, setIsPlatformAdmin] = useState(false);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | MemberStatus>('all');
  const [dialog, setDialog] = useState<DialogState>(null);
  const [busyUserId, setBusyUserId] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoadError(false);
    setMembers(null);
    try {
      const rows = await listOrgMembers();
      setMembers(rows);
    } catch {
      setLoadError(true);
    }
  }, []);

  useEffect(() => {
    load();
    supabase.auth.getUser().then(({ data }) => setSelfUserId(data.user?.id ?? null));
    checkIsPlatformAdmin().then(setIsPlatformAdmin);
  }, [load]);

  const filtered = useMemo(() => {
    if (!members) return [];
    const term = search.trim().toLowerCase();
    return members.filter((m) => {
      if (statusFilter !== 'all' && m.status !== statusFilter) return false;
      if (term && !m.email.toLowerCase().includes(term)) return false;
      return true;
    });
  }, [members, search, statusFilter]);

  const closeDialog = () => setDialog(null);

  const handleInvite = async (email: string, role: AppRole) => {
    const result = await inviteUser(email, role);
    if (!result.ok) return result;
    closeDialog();
    await load();
    showToast({
      message: `Invite sent to ${email}.`,
      actionLabel: 'Undo',
      onAction: async () => {
        const target = (await listOrgMembers()).find((m) => m.email.toLowerCase() === email.toLowerCase());
        if (target) {
          await deactivateUser(target.user_id);
          await load();
        }
      },
    });
    return result;
  };

  const handleChangeRole = async (member: OrgMember, newRole: AppRole) => {
    setBusyUserId(member.user_id);
    const result = await changeMemberRole(member.user_id, newRole);
    setBusyUserId(null);
    if (result.ok) {
      closeDialog();
      await load();
    }
    return result;
  };

  const handleDeactivate = async (member: OrgMember) => {
    setBusyUserId(member.user_id);
    const result = await deactivateUser(member.user_id);
    setBusyUserId(null);
    if (!result.ok) {
      closeDialog();
      if (result.error === 'cannot_deactivate_last_admin') setDialog({ kind: 'last-admin' });
      return result;
    }
    closeDialog();
    await load();
    showToast({
      message: `${member.email} was deactivated and signed out.`,
      actionLabel: 'Undo',
      onAction: async () => {
        await reactivateUser(member.user_id);
        await load();
      },
    });
    return result;
  };

  const handleRequestReset = async (member: OrgMember, reason: string) => {
    setBusyUserId(member.user_id);
    const result = await requestMfaReset(member.user_id, reason);
    setBusyUserId(null);
    closeDialog();
    if (result.ok) {
      showToast({ message: `Reset requested for ${member.email}. A Zyndio admin will confirm it's really them first.` });
    }
    return result;
  };

  // Zyndio (platform) admin only - performs the reset directly (reset-mfa
  // Edge Function re-checks this server side regardless of what the client
  // believes isPlatformAdmin to be).
  const handleResetMfa = async (member: OrgMember) => {
    setBusyUserId(member.user_id);
    const result = await resetMfa(member.user_id);
    setBusyUserId(null);
    closeDialog();
    if (result.ok) {
      showToast({ message: `Two-factor sign-in reset for ${member.email}. They were signed out everywhere.` });
    }
    return result;
  };

  // Own-row and deactivated rows get the menu/select stripped out entirely
  // (OVERRIDES #4 / README decision 3) - not just disabled, and re-enforced
  // server side. A Zyndio (platform) admin performs the reset directly; an
  // org admin can only ask one to (Henry's round-2 ruling).
  const buildMenuItems = useCallback(
    (m: OrgMember): RowActionItem[] => {
      if (m.status === 'deactivated') {
        return [
          {
            label: 'Reactivate',
            onClick: async () => {
              await reactivateUser(m.user_id);
              await load();
            },
          },
        ];
      }
      const items: RowActionItem[] = [];
      if (isPlatformAdmin) {
        items.push({ label: 'Reset two-factor', onClick: () => setDialog({ kind: 'reset-2fa', member: m }) });
      } else {
        items.push({ label: 'Request two-factor reset', onClick: () => setDialog({ kind: 'request-2fa-reset', member: m }) });
      }
      items.push({
        label: 'Deactivate',
        destructive: true,
        onClick: () => setDialog({ kind: 'deactivate-confirm', member: m }),
      });
      return items;
    },
    [isPlatformAdmin, load]
  );

  const columns: DataTableColumn<OrgMember>[] = [
    {
      key: 'name',
      header: 'Name',
      render: (m) => (
        <NameCell
          name={`${displayNameFromEmail(m.email)}${m.user_id === selfUserId ? ' (you)' : ''}`}
          email={m.email}
        />
      ),
    },
    {
      key: 'role',
      header: 'Role',
      render: (m) => {
        const isSelf = m.user_id === selfUserId;
        if (m.status === 'deactivated' || isSelf) {
          return <>{ROLE_LABELS[m.role]}</>;
        }
        return (
          <select
            aria-label={`Change role for ${m.email}`}
            className="min-h-[44px] rounded-md border border-slate-300 bg-white px-2 text-sm text-slate-900"
            value={m.role}
            disabled={busyUserId === m.user_id}
            onChange={(e) => setDialog({ kind: 'role-confirm', member: m, newRole: e.target.value as AppRole })}
          >
            {ASSIGNABLE_ROLES.map((r) => (
              <option key={r} value={r}>
                {ROLE_LABELS[r]}
              </option>
            ))}
          </select>
        );
      },
    },
    { key: 'twofactor', header: 'Two-factor', render: (m) => <TwoFactorStatus value={formatTwoFactor(m)} /> },
    { key: 'lastsignin', header: 'Last sign-in', render: (m) => formatLastSignIn(m) },
    { key: 'status', header: 'Status', render: (m) => renderStatusBadge(m) },
    {
      key: 'actions',
      header: 'Actions',
      render: (m) => {
        const isSelf = m.user_id === selfUserId;
        if (isSelf) {
          return <div aria-label={`More actions for ${m.email} (you)`} />;
        }
        return <RowActionsMenu email={m.email} items={buildMenuItems(m)} />;
      },
    },
  ];

  return (
    <div>
      <PageHeader
        title="Users and roles"
        description="People at Zyndio who can sign in to the care portal. Everyone must use two-factor sign-in."
        actions={
          <Button onClick={() => setDialog({ kind: 'invite' })}>Invite user</Button>
        }
      />

      {loadError && (
        <div className="mt-8 rounded-xl border border-slate-200 bg-white p-8 text-center">
          <p className="text-sm text-slate-600">
            We couldn&apos;t load the user list. Check your connection and try again. No changes were made.
          </p>
          <Button className="mt-4" variant="outline" onClick={load}>
            Try again
          </Button>
        </div>
      )}

      {!loadError && members === null && (
        <div className="mt-8 text-sm text-slate-500" role="status">
          Loading users…
        </div>
      )}

      {!loadError && members !== null && members.length === 0 && (
        <div className="mt-8 rounded-xl border border-slate-200 bg-white p-8 text-center">
          <p className="font-semibold text-[#030616]">You&apos;re the only user so far</p>
          <p className="mt-2 text-sm text-slate-600">
            Invite your physicians and care team. Each person sets their own password and two-factor sign-in from
            the invite link.
          </p>
          <Button className="mt-4" onClick={() => setDialog({ kind: 'invite' })}>
            Invite user
          </Button>
        </div>
      )}

      {!loadError && members !== null && members.length > 0 && (
        <>
          <div className="mt-6 flex flex-wrap items-center gap-3">
            <input
              type="search"
              aria-label="Search by name or email"
              placeholder="Search by name or email"
              className="min-h-[44px] flex-1 rounded-full border border-slate-300 px-4 text-sm"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
            <select
              aria-label="Filter by status"
              className="min-h-[44px] rounded-full border border-slate-300 px-4 text-sm"
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value as 'all' | MemberStatus)}
            >
              <option value="all">Status: All</option>
              <option value="active">Active</option>
              <option value="invited">Invited</option>
              <option value="deactivated">Deactivated</option>
            </select>
          </div>
          <p className="mt-3 text-sm text-slate-500">{filtered.length} people</p>
          <div className="mt-2 overflow-x-auto rounded-xl border border-slate-200 bg-white">
            <DataTable columns={columns} rows={filtered} getRowId={(m) => m.user_id} caption="Users and roles" />
          </div>
        </>
      )}

      <section className="mt-10 rounded-xl border border-slate-200 bg-white p-6">
        <div className="flex flex-wrap items-center gap-3">
          <h2 className="text-xs font-semibold uppercase tracking-wide text-slate-500">What each role can do</h2>
          <span className="rounded-full border border-amber-200 bg-amber-50 px-2.5 py-1 text-xs font-semibold text-amber-800">
            Draft, to confirm with Zyndio
          </span>
        </div>
        <dl className="mt-4 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          {ASSIGNABLE_ROLES.map((role) => (
            <div key={role}>
              <dt className="font-semibold text-[#030616]">{ROLE_LABELS[role]}</dt>
              <dd className="text-sm text-slate-600">{roleDescriptionsFor(isPlatformAdmin)[role]}</dd>
            </div>
          ))}
        </dl>
      </section>

      {dialog?.kind === 'invite' && <InviteDialog onClose={closeDialog} onSubmit={handleInvite} />}

      {dialog?.kind === 'role-confirm' && (
        <Dialog
          titleId="role-confirm-title"
          descriptionId="role-confirm-body"
          title={`Change ${dialog.member.email}'s role?`}
          onClose={closeDialog}
        >
          <p id="role-confirm-body" className="mt-2 text-sm text-slate-600">
            From {ROLE_LABELS[dialog.member.role]} to {ROLE_LABELS[dialog.newRole]}.
          </p>
          <p className="mt-2 text-sm text-slate-600">
            The change applies the next time they load a page, and it&apos;s recorded in the audit log.
          </p>
          <div className="mt-6 flex justify-end gap-3">
            <Button type="button" variant="outline" onClick={closeDialog} data-autofocus="true">
              Cancel
            </Button>
            <Button type="button" onClick={() => handleChangeRole(dialog.member, dialog.newRole)}>
              Change role
            </Button>
          </div>
        </Dialog>
      )}

      {dialog?.kind === 'deactivate-confirm' && (
        <Dialog
          titleId="deactivate-confirm-title"
          descriptionId="deactivate-confirm-body"
          title={`Deactivate ${dialog.member.email}?`}
          onClose={closeDialog}
        >
          <p id="deactivate-confirm-body" className="mt-2 text-sm text-slate-600">
            They will be signed out everywhere and won&apos;t be able to sign in. Their past activity stays in the
            audit log. You can reactivate them later.
          </p>
          <div className="mt-6 flex justify-end gap-3">
            <Button type="button" variant="outline" onClick={closeDialog} data-autofocus="true">
              Cancel
            </Button>
            <Button type="button" variant="destructive" onClick={() => handleDeactivate(dialog.member)}>
              Deactivate
            </Button>
          </div>
        </Dialog>
      )}

      {dialog?.kind === 'last-admin' && (
        <Dialog
          titleId="last-admin-title"
          descriptionId="last-admin-body"
          title="You can't deactivate the only Admin"
          onClose={closeDialog}
        >
          <p id="last-admin-body" className="mt-2 text-sm text-slate-600">
            The portal would have nobody to manage users. Make someone else an Admin first, then try again.
          </p>
          <div className="mt-6 flex justify-end">
            <Button type="button" onClick={closeDialog} data-autofocus="true">
              OK
            </Button>
          </div>
        </Dialog>
      )}

      {dialog?.kind === 'reset-2fa' && (
        <ResetTwoFactorDialog member={dialog.member} onClose={closeDialog} onConfirm={handleResetMfa} />
      )}

      {dialog?.kind === 'request-2fa-reset' && (
        <RequestTwoFactorResetDialog member={dialog.member} onClose={closeDialog} onSubmit={handleRequestReset} />
      )}
    </div>
  );
};

// Zyndio (platform) admin only (copy-deck "### reset-2fa"). Performs the
// reset directly via reset-mfa - destructive, so the confirm button matches
// the deactivate dialog's red/destructive styling.
const ResetTwoFactorDialog: React.FC<{
  member: OrgMember;
  onClose: () => void;
  onConfirm: (member: OrgMember) => Promise<{ ok: boolean; error?: string }>;
}> = ({ member, onClose, onConfirm }) => {
  const [submitting, setSubmitting] = useState(false);

  return (
    <Dialog
      titleId="reset-2fa-title"
      descriptionId="reset-2fa-body"
      title={`Reset two-factor sign-in for ${member.email}?`}
      onClose={onClose}
    >
      <div className="mt-4 flex gap-2 rounded-xl border border-amber-200 bg-amber-50 p-3 text-sm text-amber-800">
        <span aria-hidden="true">⚠️</span>
        <p>
          Only do this after you&apos;ve confirmed it&apos;s really {member.email}, for example on a video call.
          Never because of an email alone.
        </p>
      </div>
      <p id="reset-2fa-body" className="mt-4 text-sm text-slate-600">
        Their authenticator app and recovery codes will stop working, and they&apos;re signed out on every device.
        At next sign-in, they&apos;ll set up two-factor sign-in again. The reset is recorded in the audit log.
      </p>
      <p className="mt-2 text-sm text-slate-500">Only Zyndio admins can reset two-factor sign-in.</p>
      <div className="mt-6 flex justify-end gap-3">
        <Button type="button" variant="outline" onClick={onClose} data-autofocus="true">
          Cancel
        </Button>
        <Button
          type="button"
          variant="destructive"
          busy={submitting}
          busyLabel="Resetting…"
          onClick={async () => {
            setSubmitting(true);
            await onConfirm(member);
            setSubmitting(false);
          }}
        >
          Reset two-factor
        </Button>
      </div>
    </Dialog>
  );
};

// Org admin only - can only ask, never perform (copy-deck doesn't have this
// state yet; copy follows the request-2fa-reset / reset-requested renders).
const RequestTwoFactorResetDialog: React.FC<{
  member: OrgMember;
  onClose: () => void;
  onSubmit: (member: OrgMember, reason: string) => Promise<{ ok: boolean; error?: string }>;
}> = ({ member, onClose, onSubmit }) => {
  const [reason, setReason] = useState('');
  const [submitting, setSubmitting] = useState(false);

  return (
    <Dialog
      titleId="request-2fa-reset-title"
      descriptionId="request-2fa-reset-body"
      title={`Ask for a two-factor reset for ${member.email}?`}
      onClose={onClose}
    >
      <p id="request-2fa-reset-body" className="mt-2 text-sm text-slate-600">
        Only a Zyndio admin can reset two-factor sign-in. They&apos;ll confirm it&apos;s really them before they
        reset it, then they&apos;re signed out on every device and set it up again at next sign-in.
      </p>
      <div className="mt-4">
        <label htmlFor="request-2fa-reset-reason" className="text-sm font-semibold text-[#030616]">
          Reason (optional)
        </label>
        <input
          id="request-2fa-reset-reason"
          type="text"
          className="mt-1 min-h-[44px] w-full rounded-md border border-slate-300 px-3 text-sm"
          placeholder="e.g. they got a new phone and can't open the authenticator app"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          data-autofocus="true"
        />
        <p className="mt-1 text-xs text-slate-500">Zyndio admins see this with your name and time.</p>
      </div>
      <div className="mt-6 flex justify-end gap-3">
        <Button type="button" variant="outline" onClick={onClose}>
          Cancel
        </Button>
        <Button
          type="button"
          busy={submitting}
          busyLabel="Sending…"
          onClick={async () => {
            setSubmitting(true);
            await onSubmit(member, reason);
            setSubmitting(false);
          }}
        >
          Send request
        </Button>
      </div>
    </Dialog>
  );
};

interface InviteDialogProps {
  onClose: () => void;
  onSubmit: (email: string, role: AppRole) => Promise<{ ok: boolean; error?: string }>;
}

const InviteDialog: React.FC<InviteDialogProps> = ({ onClose, onSubmit }) => {
  const [email, setEmail] = useState('');
  const [role, setRole] = useState<AppRole>('physician');
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim()) {
      setError('Enter a work email.');
      return;
    }
    setSubmitting(true);
    setError(null);
    const result = await onSubmit(email.trim(), role);
    setSubmitting(false);
    if (!result.ok) {
      setError(
        result.error === 'email_in_use' || result.error === 'already_registered'
          ? 'Someone with this email already has an account.'
          : "We couldn't send the invite. Try again."
      );
    }
  };

  return (
    <Dialog titleId="invite-title" title="Invite a user" onClose={onClose} initialFocusSelector="#invite-email">
      <p className="mt-2 text-sm text-slate-600">
        They&apos;ll get an email with a link to set a password and two-factor sign-in. The link works for 7 days.
      </p>
      <form onSubmit={handleSubmit} className="mt-4 space-y-4">
        <div>
          <label htmlFor="invite-email" className="text-sm font-semibold text-[#030616]">
            Work email
          </label>
          <input
            id="invite-email"
            type="email"
            required
            className="mt-1 min-h-[44px] w-full rounded-md border border-slate-300 px-3 text-sm"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            aria-describedby={error ? 'invite-email-error' : undefined}
            aria-invalid={error ? true : undefined}
          />
          {error && (
            <p id="invite-email-error" className="mt-1 text-sm text-red-600" role="alert">
              {error}
            </p>
          )}
        </div>
        <div>
          <span className="text-sm font-semibold text-[#030616]">Role</span>
          <div className="mt-2 space-y-2">
            {ASSIGNABLE_ROLES.map((r) => (
              <label key={r} className="flex items-start gap-2 text-sm">
                <input
                  type="radio"
                  name="invite-role"
                  value={r}
                  checked={role === r}
                  onChange={() => setRole(r)}
                  className="mt-1"
                />
                <span>
                  <span className="font-semibold text-[#030616]">{ROLE_LABELS[r]}</span>
                  <br />
                  <span className="text-slate-600">{ROLE_DESCRIPTIONS[r]}</span>
                </span>
              </label>
            ))}
          </div>
        </div>
        <div className="flex justify-end gap-3">
          <Button type="button" variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" busy={submitting} busyLabel="Sending…">
            Send invite
          </Button>
        </div>
      </form>
    </Dialog>
  );
};

export default UsersRolesPage;
