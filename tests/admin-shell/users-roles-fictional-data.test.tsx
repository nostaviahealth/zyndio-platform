// @vitest-environment jsdom
// TC-013 Ava L9: the live Users and roles page only shows the
// "FICTIONAL DATA" tag in preview/demo builds (__PREVIEW_BUILD__), never in
// the default production bundle.
import React from 'react';
import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';

const MEMBERS = [
  {
    user_id: 'self-1',
    email: 'taylor.brooks@example.test',
    full_name: null,
    role: 'org_admin',
    status: 'active',
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
  },
];

vi.mock('../../lib/usersRolesApi', () => ({
  listOrgMembers: vi.fn(async () => MEMBERS),
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

function renderPage() {
  return render(
    <ToastProvider>
      <UsersRolesPage />
    </ToastProvider>
  );
}

describe('UsersRolesPage fictional data tag', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('is absent when __PREVIEW_BUILD__ is not set (default production build)', async () => {
    renderPage();
    await waitFor(() => expect(screen.getByText('1 people')).toBeInTheDocument());
    expect(screen.queryByText('Fictional data')).not.toBeInTheDocument();
  });

  it('shows the tag when __PREVIEW_BUILD__ is true', async () => {
    vi.stubGlobal('__PREVIEW_BUILD__', true);
    renderPage();
    await waitFor(() => expect(screen.getByText('1 people')).toBeInTheDocument());
    expect(screen.getByText('Fictional data')).toBeInTheDocument();
  });
});
