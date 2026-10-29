// @vitest-environment jsdom
// TC-021 item 20 (sidebar sign-out focus ring) and item 21 (Ava's Low on #21:
// inset focus ring on ⋯ menu items). Class/token level; the computed
// box-shadow checks run on the real app in scripts/tc019_theme_check.py.
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';

const mockUsePortalAuth = vi.fn();
vi.mock('../../contexts/PortalAuthContext', () => ({
  usePortalAuth: () => mockUsePortalAuth(),
}));

import Sidebar from '../../components/admin-shell/Sidebar';
import RowActionsMenu from '../../components/ui/RowActionsMenu';
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

function luminance(hex: string): number {
  const [r, g, b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255).map((c) =>
    c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4
  );
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}
function contrast(a: string, b: string): number {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
}

// Backgrounds a focused menu item can sit on: the panel (bg-white /
// dark:bg-[#10141F]) and the item hover fill (slate-50 / #222838).
const ITEM_BACKGROUNDS = { light: ['#FFFFFF', '#F8FAFC'], dark: ['#10141F', '#222838'] };

describe('item 21: ⋯ menu items use an inset focus ring (no offset), >= 3:1 in both themes', () => {
  async function renderMenuItems() {
    render(<RowActionsMenu email="jamie.ortiz@example.test" items={[{ label: 'Change role', onClick: vi.fn() }, { label: 'Deactivate', onClick: vi.fn(), destructive: true }]} />);
    await userEvent.setup().click(screen.getByRole('button', { name: 'More actions for jamie.ortiz@example.test' }));
    await screen.findByRole('menu');
    return screen.getAllByRole('menuitem');
  }

  it('every menu item has a 3px inset ring in the focus token colours and no ring offset', async () => {
    for (const item of await renderMenuItems()) {
      const cls = classesOf(item);
      expect(cls).toEqual(
        expect.arrayContaining([
          'focus:ring-[3px]', 'focus-visible:ring-[3px]',
          'focus:ring-inset', 'focus-visible:ring-inset',
          'focus:ring-[#2346DD]', 'focus-visible:ring-[#2346DD]',
          'dark:focus:ring-[#AFC3FF]', 'dark:focus-visible:ring-[#AFC3FF]',
        ])
      );
      expect(cls.filter((c) => /ring-offset/.test(c))).toEqual([]);
    }
  });

  it('the ring colour is >= 3:1 against every background a focused item sits on, in both themes', async () => {
    const [item] = await renderMenuItems();
    const cls = classesOf(item);
    const light = cls.find((c) => /^focus-visible:ring-\[#[0-9A-Fa-f]{6}\]$/.test(c))?.match(/#[0-9A-Fa-f]{6}/)?.[0];
    const dark = cls.find((c) => /^dark:focus-visible:ring-\[#[0-9A-Fa-f]{6}\]$/.test(c))?.match(/#[0-9A-Fa-f]{6}/)?.[0];
    expect(light).toBeDefined();
    expect(dark).toBeDefined();
    for (const bg of ITEM_BACKGROUNDS.light) expect(contrast(light!, bg)).toBeGreaterThanOrEqual(3);
    for (const bg of ITEM_BACKGROUNDS.dark) expect(contrast(dark!, bg)).toBeGreaterThanOrEqual(3);
  });
});
