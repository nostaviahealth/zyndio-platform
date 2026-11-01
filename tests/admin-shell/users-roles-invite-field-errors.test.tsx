// @vitest-environment jsdom
// TC-018 item 1 (L33): the invite dialog maps a 400-with-field-name
// response (invite-user's {error:'invalid_request', field:'full_name'|'email'})
// to an inline error on that specific field, instead of falling through to
// the generic banner error. Client-side maxlength (name 120, email 254) is
// a UX cap only - the server stays the validation authority.
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

const MEMBERS = [
  {
    user_id: 'self-1',
    email: 'taylor.brooks@example.test',
    full_name: 'Taylor Brooks',
    role: 'org_admin',
    status: 'active',
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
  },
];

const inviteUser = vi.fn(async () => ({ ok: true }));

vi.mock('../../lib/usersRolesApi', () => ({
  listOrgMembers: vi.fn(async () => MEMBERS),
  inviteUser: (...args: unknown[]) => inviteUser(...args),
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

vi.mock('../../components/ui/Toast', () => ({
  useToast: () => ({ showToast: vi.fn() }),
}));

import UsersRolesPage from '../../pages/admin/UsersRoles';

async function openDialogAndFill(user: ReturnType<typeof userEvent.setup>) {
  render(<UsersRolesPage />);
  await screen.findByRole('button', { name: /invite user/i });
  await user.click(screen.getByRole('button', { name: /invite user/i }));
  await user.type(screen.getByLabelText(/full name/i), 'Alex Lindgren');
  await user.type(screen.getByLabelText(/work email/i), 'alex.lindgren@example.test');
  await user.click(screen.getByRole('radio', { name: /physician/i }));
}

describe('UsersRolesPage invite dialog field-level errors (TC-018 item 1, L33)', () => {
  beforeEach(() => {
    inviteUser.mockClear();
    inviteUser.mockResolvedValue({ ok: true });
  });

  it('shows an inline email error on a 400 with field "email", not the generic banner', async () => {
    inviteUser.mockResolvedValueOnce({ ok: false, error: 'invalid_request', field: 'email' });
    const user = userEvent.setup();
    await openDialogAndFill(user);
    await user.click(screen.getByRole('button', { name: /^send invite$/i }));
    expect(await screen.findByLabelText(/work email/i)).toHaveAttribute('aria-invalid', 'true');
    expect(
      screen.queryByText("We couldn't send the invite. Nothing was saved. Check your connection and try again.")
    ).toBeNull();
  });

  it('shows an inline full-name error on a 400 with field "full_name", not the generic banner', async () => {
    inviteUser.mockResolvedValueOnce({ ok: false, error: 'invalid_request', field: 'full_name' });
    const user = userEvent.setup();
    await openDialogAndFill(user);
    await user.click(screen.getByRole('button', { name: /^send invite$/i }));
    expect(await screen.findByLabelText(/full name/i)).toHaveAttribute('aria-invalid', 'true');
    expect(
      screen.queryByText("We couldn't send the invite. Nothing was saved. Check your connection and try again.")
    ).toBeNull();
  });

  it('caps full name input at 120 characters and email at 254', async () => {
    const user = userEvent.setup();
    render(<UsersRolesPage />);
    await screen.findByRole('button', { name: /invite user/i });
    await user.click(screen.getByRole('button', { name: /invite user/i }));
    expect(screen.getByLabelText(/full name/i)).toHaveAttribute('maxLength', '120');
    expect(screen.getByLabelText(/work email/i)).toHaveAttribute('maxLength', '254');
  });
});
