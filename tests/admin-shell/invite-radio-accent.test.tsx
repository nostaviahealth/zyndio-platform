// @vitest-environment jsdom
// TC-019 M6 (Ava must-fix): native radios must follow the theme via
// accent-color. The invite-role radios used a hardcoded accent-[#2C5CF2]
// regardless of theme; they must use the focus.ring token colour instead
// (#2346DD light / #AFC3FF dark) so dark-mode radios aren't a stray light-
// blue accent on a dark dialog.
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

vi.mock('../../lib/usersRolesApi', () => ({
  listOrgMembers: vi.fn(async () => []),
  inviteUser: vi.fn(async () => ({ ok: true })),
  cancelInvite: vi.fn(async () => ({ ok: true })),
  changeMemberRole: vi.fn(async () => ({ ok: true })),
  deactivateUser: vi.fn(async () => ({ ok: true })),
  reactivateUser: vi.fn(async () => ({ ok: true })),
  requestMfaReset: vi.fn(async () => ({ ok: true })),
  resetMfa: vi.fn(async () => ({ ok: true })),
  checkIsPlatformAdmin: vi.fn(async () => false),
}));

vi.mock('../../lib/supabase', () => ({
  supabase: {
    auth: { getUser: vi.fn(async () => ({ data: { user: { id: 'self-1' } } })) },
  },
}));

import UsersRolesPage from '../../pages/admin/UsersRoles';
import { ToastProvider } from '../../components/ui/Toast';

describe('Invite dialog role radio accent-color (Ava M6)', () => {
  beforeEach(() => vi.clearAllMocks());

  it('uses the focus-ring token colours, not the hardcoded #2C5CF2', async () => {
    const user = userEvent.setup();
    render(
      <ToastProvider>
        <UsersRolesPage />
      </ToastProvider>
    );
    await waitFor(() => expect(screen.getByText("You're the only user so far")).toBeInTheDocument());
    await user.click(screen.getAllByRole('button', { name: 'Invite user' })[0]);
    const radio = (await screen.findAllByRole('radio'))[0];
    expect(radio.className).toMatch(/accent-\[#2346DD\]/);
    expect(radio.className).toMatch(/dark:accent-\[#AFC3FF\]/);
    expect(radio.className).not.toMatch(/accent-\[#2C5CF2\]/);
  });
});
