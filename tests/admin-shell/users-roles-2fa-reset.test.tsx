// @vitest-environment jsdom
// TC-011: role gating for the two 2FA-reset dialogs - a Zyndio (platform)
// admin sees "Reset two-factor" (performs the reset via reset-mfa); an org
// admin sees "Request 2FA reset" (can only ask, via request_mfa_reset()).
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

const MEMBERS = [
  {
    user_id: 'self-1',
    email: 'taylor.brooks@example.test',
    role: 'org_admin',
    status: 'active',
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
  },
  {
    user_id: 'other-1',
    email: 'priya.raman@example.test',
    role: 'physician',
    status: 'active',
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
  },
];

const resetMfa = vi.fn(async () => ({ ok: true }));
const requestMfaReset = vi.fn(async () => ({ ok: true }));
let isPlatformAdmin = false;

vi.mock('../../lib/usersRolesApi', () => ({
  listOrgMembers: vi.fn(async () => MEMBERS),
  inviteUser: vi.fn(async () => ({ ok: true })),
  changeMemberRole: vi.fn(async () => ({ ok: true })),
  deactivateUser: vi.fn(async () => ({ ok: true })),
  reactivateUser: vi.fn(async () => ({ ok: true })),
  requestMfaReset: (...args: unknown[]) => requestMfaReset(...args),
  resetMfa: (...args: unknown[]) => resetMfa(...args),
  checkIsPlatformAdmin: vi.fn(async () => isPlatformAdmin),
}));

vi.mock('../../lib/supabase', () => ({
  supabase: {
    auth: { getUser: vi.fn(async () => ({ data: { user: { id: 'self-1' } } })) },
  },
}));

import UsersRolesPage from '../../pages/admin/UsersRoles';
import { ToastProvider } from '../../components/ui/Toast';

function renderPage() {
  return render(
    <ToastProvider>
      <UsersRolesPage />
    </ToastProvider>
  );
}

describe('UsersRolesPage 2FA reset role gating', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    isPlatformAdmin = false;
  });

  it('an org admin (not a Zyndio admin) sees "Request 2FA reset", not "Reset two-factor"', async () => {
    isPlatformAdmin = false;
    renderPage();
    await waitFor(() => expect(screen.getByText('2 people')).toBeInTheDocument());
    expect(await screen.findByRole('button', { name: 'Request 2FA reset' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Reset two-factor' })).not.toBeInTheDocument();
  });

  it('a Zyndio admin sees "Reset two-factor", not "Request 2FA reset"', async () => {
    isPlatformAdmin = true;
    renderPage();
    await waitFor(() => expect(screen.getByText('2 people')).toBeInTheDocument());
    expect(await screen.findByRole('button', { name: 'Reset two-factor' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Request 2FA reset' })).not.toBeInTheDocument();
  });

  it('org admin: the request dialog calls requestMfaReset(), never resetMfa()', async () => {
    isPlatformAdmin = false;
    const user = userEvent.setup();
    renderPage();
    await waitFor(() => expect(screen.getByText('2 people')).toBeInTheDocument());
    await user.click(await screen.findByRole('button', { name: 'Request 2FA reset' }));
    expect(await screen.findByText("Ask for a two-factor reset for priya.raman@example.test?")).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Send request' }));
    await waitFor(() => expect(requestMfaReset).toHaveBeenCalledWith('other-1', ''));
    expect(resetMfa).not.toHaveBeenCalled();
  });

  it('Zyndio admin: the reset dialog calls resetMfa(), never requestMfaReset()', async () => {
    isPlatformAdmin = true;
    const user = userEvent.setup();
    renderPage();
    await waitFor(() => expect(screen.getByText('2 people')).toBeInTheDocument());
    await user.click(await screen.findByRole('button', { name: 'Reset two-factor' }));
    expect(await screen.findByText('Reset two-factor sign-in for priya.raman@example.test?')).toBeInTheDocument();
    const dialog = screen.getByRole('alertdialog');
    await user.click(within(dialog).getByRole('button', { name: 'Reset two-factor' }));
    await waitFor(() => expect(resetMfa).toHaveBeenCalledWith('other-1'));
    expect(requestMfaReset).not.toHaveBeenCalled();
  });

  it("the role legend's Admin description differs for a Zyndio admin vs an org admin", async () => {
    isPlatformAdmin = true;
    renderPage();
    await waitFor(() =>
      expect(screen.getByText('Invites people, assigns roles, deactivates accounts, resets two-factor sign-in.')).toBeInTheDocument()
    );
  });
});
