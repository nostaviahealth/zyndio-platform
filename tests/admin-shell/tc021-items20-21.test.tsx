// @vitest-environment jsdom
// TC-021 item 20 (sidebar sign-out focus ring) and item 21 (Ava's Low on #21:
// inset focus ring on ⋯ menu items). Class/token level; the computed
// box-shadow checks run on the real app in scripts/tc019_theme_check.py.
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

const mockUsePortalAuth = vi.fn();
vi.mock('../../contexts/PortalAuthContext', () => ({
  usePortalAuth: () => mockUsePortalAuth(),
}));

import Sidebar from '../../components/admin-shell/Sidebar';
import { FOCUS_RING_ON_SUNKEN_CLASS } from '../../components/ui/focusRing';

const tokens = (cls: string) => cls.split(/\s+/).filter(Boolean);
const classesOf = (el: Element) => tokens(el.getAttribute('class') ?? '');

describe('item 20: sidebar sign-out button focus ring', () => {
  it.each(['org_admin', 'physician'])('the sign-out button carries the same focus-ring tokens as the sidebar links (%s)', (role) => {
    mockUsePortalAuth.mockReturnValue({ role, email: 'casey.morgan@example.test', signOut: vi.fn() });
    render(
      <MemoryRouter initialEntries={['/admin']}>
        <Sidebar />
      </MemoryRouter>
    );
    const link = screen.getAllByRole('link')[0];
    const signOut = screen.getByRole('button', { name: 'Sign out' });
    const ring = tokens(FOCUS_RING_ON_SUNKEN_CLASS);
    expect(classesOf(link)).toEqual(expect.arrayContaining(ring));
    expect(classesOf(signOut)).toEqual(expect.arrayContaining(ring));
  });
});
