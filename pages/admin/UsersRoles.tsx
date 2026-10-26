import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { supabase } from '../../lib/supabase';
import {
  AppRole,
  MemberStatus,
  OrgMember,
  changeMemberRole,
  deactivateUser,
  inviteUser,
  listOrgMembers,
  reactivateUser,
  requestMfaReset,
} from '../../lib/usersRolesApi';
import PageHeader from '../../components/ui/PageHeader';
import DataTable, { DataTableColumn } from '../../components/ui/DataTable';
import Dialog from '../../components/ui/Dialog';
import { useToast } from '../../components/ui/Toast';
import Button from '../../components/admin-auth/Button';

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

const ASSIGNABLE_ROLES: AppRole[] = ['physician', 'care_coordinator', 'org_admin', 'read_only'];

const STATUS_LABELS: Record<MemberStatus, string> = {
  invited: 'Invited',
  active: 'Active',
  deactivated: 'Deactivated',
};

function formatLastSignIn(member: OrgMember): string {
  // list_org_members() doesn't surface auth.users.last_sign_in_at yet (would
  // need a service-role join beyond this step's scope) - invited members
  // have never signed in by definition; everyone else is "unknown" rather
  // than a fabricated date.
  return member.status === 'invited' ? 'Never' : 'Unknown';
}

function formatTwoFactor(member: OrgMember): string {
  return member.status === 'invited' ? 'Not set up yet' : 'Unknown';
}

type DialogState =
  | { kind: 'invite' }
  | { kind: 'role-confirm'; member: OrgMember; newRole: AppRole }
  | { kind: 'deactivate-confirm'; member: OrgMember }
  | { kind: 'last-admin' }
  | { kind: 'reset-2fa'; member: OrgMember }
  | null;

const UsersRolesPage: React.FC = () => {
  const { showToast } = useToast();
  const [members, setMembers] = useState<OrgMember[] | null>(null);
  const [loadError, setLoadError] = useState(false);
  const [selfUserId, setSelfUserId] = useState<string | null>(null);
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

  const handleRequestReset = async (member: OrgMember) => {
    setBusyUserId(member.user_id);
    const result = await requestMfaReset(member.user_id);
    setBusyUserId(null);
    closeDialog();
    if (result.ok) {
      showToast({ message: `Reset requested for ${member.email}. A Zyndio admin will confirm their identity first.` });
    }
    return result;
  };

  const columns: DataTableColumn<OrgMember>[] = [
    { key: 'email', header: 'Name', render: (m) => <>{m.email}{m.user_id === selfUserId ? ' (you)' : ''}</> },
    { key: 'role', header: 'Role', render: (m) => ROLE_LABELS[m.role] },
    { key: 'twofactor', header: 'Two-factor', render: (m) => formatTwoFactor(m) },
    { key: 'lastsignin', header: 'Last sign-in', render: (m) => formatLastSignIn(m) },
    { key: 'status', header: 'Status', render: (m) => STATUS_LABELS[m.status] },
    {
      key: 'actions',
      header: 'Actions',
      render: (m) => {
        const isSelf = m.user_id === selfUserId;
        return (
          <div className="flex gap-2" aria-label={`More actions for ${m.email}${isSelf ? ' (you)' : ''}`}>
            {m.status !== 'deactivated' && (
              <>
                <select
                  aria-label={`Change role for ${m.email}`}
                  className="rounded-md border border-slate-300 px-2 py-1 text-xs"
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
                {/* Own-row: no reset-2fa, no deactivate (OVERRIDES #4 / README decision 3) -
                    hidden entirely, not just disabled, and re-enforced server side. */}
                {!isSelf && (
                  <button
                    type="button"
                    className="text-xs font-semibold text-[#2C5CF2] hover:underline"
                    onClick={() => setDialog({ kind: 'reset-2fa', member: m })}
                  >
                    Request 2FA reset
                  </button>
                )}
                {!isSelf && (
                  <button
                    type="button"
                    className="text-xs font-semibold text-red-600 hover:underline"
                    onClick={() => setDialog({ kind: 'deactivate-confirm', member: m })}
                  >
                    Deactivate
                  </button>
                )}
              </>
            )}
            {m.status === 'deactivated' && (
              <button
                type="button"
                className="text-xs font-semibold text-[#2C5CF2] hover:underline"
                onClick={async () => {
                  await reactivateUser(m.user_id);
                  await load();
                }}
              >
                Reactivate
              </button>
            )}
          </div>
        );
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
        <h2 className="text-xs font-semibold uppercase tracking-wide text-slate-500">
          What each role can do <span className="normal-case text-slate-400">(Draft, to confirm with Zyndio)</span>
        </h2>
        <dl className="mt-4 grid gap-4 sm:grid-cols-2">
          {ASSIGNABLE_ROLES.map((role) => (
            <div key={role}>
              <dt className="font-semibold text-[#030616]">{ROLE_LABELS[role]}</dt>
              <dd className="text-sm text-slate-600">{ROLE_DESCRIPTIONS[role]}</dd>
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
        <Dialog
          titleId="reset-2fa-title"
          descriptionId="reset-2fa-body"
          title={`Ask a Zyndio admin to reset two-factor sign-in for ${dialog.member.email}?`}
          onClose={closeDialog}
        >
          <p id="reset-2fa-body" className="mt-2 text-sm text-slate-600">
            A Zyndio admin will confirm it&apos;s really them (for example on a video call) before resetting. This
            request is recorded in the audit log.
          </p>
          <div className="mt-6 flex justify-end gap-3">
            <Button type="button" variant="outline" onClick={closeDialog} data-autofocus="true">
              Cancel
            </Button>
            <Button type="button" onClick={() => handleRequestReset(dialog.member)}>
              Request reset
            </Button>
          </div>
        </Dialog>
      )}
    </div>
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
