// @vitest-environment jsdom
// TC-019 light-contrast must-fix (Ava L-b/L-c/L-d): in light mode (what a
// dark-OS user is NOT in, but what everyone else sees) the "N people"
// count was 4.32:1, the table header text was 4.02:1, and the search
// border was 1.35:1 against the canvas / 1.48:1 against its own white
// fill. All three must clear AA (4.5:1 text, 3:1 border).
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
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
import SearchField from '../../components/ui/SearchField';

function renderPage() {
  return render(
    <ToastProvider>
      <UsersRolesPage />
    </ToastProvider>
  );
}

describe('"N people" count contrast (Ava L-b)', () => {
  it('uses #48556A instead of slate-500 (#64748B, 4.32:1)', async () => {
    renderPage();
    const count = await screen.findByText('1 people');
    expect(count.className).toMatch(/text-\[#48556A\]/);
    expect(count.className).not.toMatch(/text-slate-500/);
  });
});

describe('Table header text contrast (Ava L-c)', () => {
  it('uses a ≥4.5:1 color on the E6ECFA header background instead of slate-500 (4.02:1)', async () => {
    renderPage();
    await waitFor(() => expect(screen.getByText('1 people')).toBeInTheDocument());
    const header = screen.getByRole('columnheader', { name: 'Name' });
    const headerRow = header.parentElement!;
    expect(headerRow.className).toMatch(/dark:bg-\[#0B0F19\]/); // unchanged dark token
    expect(headerRow.className).not.toMatch(/\btext-slate-500\b/);
    expect(headerRow.className).toMatch(/text-\[#48556A\]/);
  });
});

describe('Search field border contrast (Ava L-d)', () => {
  it('uses #6C7690 instead of slate-300 (1.35:1 vs canvas, 1.48:1 vs own fill)', () => {
    render(<SearchField aria-label="Search by name or email" placeholder="Search" />);
    const input = screen.getByLabelText('Search by name or email');
    expect(input.className).toMatch(/border-\[#6C7690\]/);
    expect(input.className).not.toMatch(/border-slate-300/);
  });
});
