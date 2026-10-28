// @vitest-environment jsdom
// TC-013 Ava M5: two-factor column shows a check icon + "On", or
// "Not set up yet" as secondary text with no icon.
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor, within } from '@testing-library/react';

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
    user_id: 'other-invited',
    email: 'sam.okafor@example.test',
    role: 'care_coordinator',
    status: 'invited',
    created_at: '2026-10-25T00:00:00Z',
    updated_at: '2026-10-25T00:00:00Z',
  },
];

vi.mock('../../lib/usersRolesApi', () => ({
  listOrgMembers: vi.fn(async () => MEMBERS),
  inviteUser: vi.fn(async () => ({ ok: true })),
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

function renderPage() {
  return render(
    <ToastProvider>
      <UsersRolesPage />
    </ToastProvider>
  );
}

describe('UsersRolesPage two-factor column', () => {
  it('"Not set up yet" renders as secondary text with no check icon', async () => {
    renderPage();
    await waitFor(() => expect(screen.getByText('2 people')).toBeInTheDocument());
    const text = screen.getByText('Not set up yet');
    expect(text.className).toMatch(/text-slate-500/);
    const cell = text.closest('td') as HTMLElement;
    expect(cell.querySelector('svg')).toBeNull();
  });
});
