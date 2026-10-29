// @vitest-environment jsdom
// TC-021 round 2, UI items 6, 7, 10, 13, 14 (fail-first). Class/token level;
// the real-browser checks (computed colours, hit-tests, scrolling, focus
// rings, captures) are in scripts/tc019_theme_check.py, which now runs in CI.
import React from 'react';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, it, expect, vi } from 'vitest';
import { render, screen, act } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';

const mockUsePortalAuth = vi.fn();
vi.mock('../../contexts/PortalAuthContext', () => ({
  usePortalAuth: () => mockUsePortalAuth(),
}));
vi.mock('../../lib/supabase', () => {
  const builder: Record<string, unknown> = {};
  for (const m of ['select', 'eq', 'order', 'insert', 'update', 'delete', 'upsert', 'single']) builder[m] = () => builder;
  builder.then = (resolve: (v: unknown) => unknown) => Promise.resolve({ data: [], error: null }).then(resolve);
  return { supabase: { from: () => builder } };
});

import RowActionsMenu from '../../components/ui/RowActionsMenu';
import DataTable, { type DataTableColumn } from '../../components/ui/DataTable';
import Sidebar from '../../components/admin-shell/Sidebar';
import IdleWarningDialog from '../../components/admin-shell/IdleWarningDialog';
import { AdminProvider, useAdmin } from '../../contexts/AdminContext';
import { FOCUS_RING_CLASS, FOCUS_RING_ON_SUNKEN_CLASS } from '../../components/ui/focusRing';

const tokens = (cls: string) => cls.split(/\s+/).filter(Boolean);
const classesOf = (el: Element) => tokens(el.getAttribute('class') ?? '');

async function openMenu(email = 'last.row@example.test') {
  const user = userEvent.setup();
  await user.click(screen.getByRole('button', { name: `More actions for ${email}` }));
  return { user, menu: await screen.findByRole('menu') };
}

describe('item 6: the ⋯ menu has dark tokens', () => {
  it('panel uses bg.surface / border.subtle in dark', async () => {
    render(<RowActionsMenu email="last.row@example.test" items={[{ label: 'Reactivate', onClick: vi.fn() }]} />);
    const { menu } = await openMenu();
    expect(classesOf(menu)).toEqual(expect.arrayContaining(['dark:bg-[#10141F]', 'dark:border-[#222838]']));
  });

  it('items use text.primary, status.critical (destructive) and a dark hover', async () => {
    render(
      <RowActionsMenu
        email="last.row@example.test"
        items={[
          { label: 'Request two-factor reset', onClick: vi.fn() },
          { label: 'Deactivate', onClick: vi.fn(), destructive: true },
        ]}
      />
    );
    await openMenu();
    const plain = screen.getByRole('menuitem', { name: 'Request two-factor reset' });
    const destructive = screen.getByRole('menuitem', { name: 'Deactivate' });
    expect(classesOf(plain)).toEqual(expect.arrayContaining(['dark:text-[#EEF1F8]', 'dark:hover:bg-[#222838]']));
    expect(classesOf(destructive)).toEqual(expect.arrayContaining(['dark:text-[#FF8F86]', 'dark:hover:bg-[#222838]']));
  });

  it("clicks the LAST row's menu in a scrolling DataTable and runs Reactivate once", async () => {
    type Row = { id: string; email: string };
    const rows: Row[] = Array.from({ length: 12 }, (_, i) => ({ id: `r${i}`, email: `person${i}@example.test` }));
    const reactivate = vi.fn();
    const columns: DataTableColumn<Row>[] = [
      { key: 'email', header: 'Email', render: (r) => r.email },
      {
        key: 'actions',
        header: 'Actions',
        stickyRight: true,
        render: (r) => <RowActionsMenu email={r.email} items={[{ label: 'Reactivate', onClick: () => reactivate(r.id) }]} />,
      },
    ];
    render(<DataTable columns={columns} rows={rows} getRowId={(r) => r.id} />);
    const { user, menu } = await openMenu('person11@example.test');
    expect(menu.closest('table')).toBeNull(); // rendered outside the table
    await user.click(screen.getByRole('menuitem', { name: 'Reactivate' }));
    expect(reactivate).toHaveBeenCalledTimes(1);
    expect(reactivate).toHaveBeenCalledWith('r11');
  });
});

describe('item 7: menu focus ring, focus on open, arrows; themed scrollbar', () => {
  it('every menu item carries the focus-ring token classes', async () => {
    render(
      <RowActionsMenu email="last.row@example.test" items={[{ label: 'A', onClick: vi.fn() }, { label: 'B', onClick: vi.fn() }]} />
    );
    await openMenu();
    for (const item of screen.getAllByRole('menuitem')) {
      // Item 21 (Ava, #21): menu items keep the token ring but drop the
      // 2px offset (inset instead; see tc021-items20-21.test.tsx).
      expect(classesOf(item)).toEqual(expect.arrayContaining(tokens(FOCUS_RING_CLASS).filter((t) => !/ring-offset/.test(t))));
    }
  });

  it('opening by click moves focus to the first item; arrows move between items', async () => {
    render(
      <RowActionsMenu
        email="last.row@example.test"
        items={[{ label: 'A', onClick: vi.fn() }, { label: 'B', onClick: vi.fn() }, { label: 'C', onClick: vi.fn() }]}
      />
    );
    const { user } = await openMenu();
    expect(screen.getByRole('menuitem', { name: 'A' })).toHaveFocus();
    await user.keyboard('{ArrowDown}');
    expect(screen.getByRole('menuitem', { name: 'B' })).toHaveFocus();
    await user.keyboard('{ArrowUp}{ArrowUp}');
    expect(screen.getByRole('menuitem', { name: 'C' })).toHaveFocus();
  });

  it('index.html gives the scrollbar thumb a dark-theme colour (border.strong #6C7690)', () => {
    const html = readFileSync(resolve(__dirname, '../../index.html'), 'utf8');
    expect(html).toMatch(/html\.dark\s+::-webkit-scrollbar-thumb\s*\{[^}]*background:\s*#6C7690/i);
  });
});

describe('item 10: pinned actions column edge (F2) and sidebar link focus ring (F5)', () => {
  it('pinned header and cells draw a left edge in both themes', () => {
    const columns: DataTableColumn<{ id: string }>[] = [
      { key: 'id', header: 'Id', render: (r) => r.id },
      { key: 'actions', header: 'Actions', stickyRight: true, render: () => 'x' },
    ];
    render(<DataTable columns={columns} rows={[{ id: 'a' }]} getRowId={(r) => r.id} />);
    const th = screen.getByRole('columnheader', { name: 'Actions' });
    const td = screen.getByRole('cell', { name: 'x' });
    for (const el of [th, td]) {
      expect(classesOf(el)).toEqual(expect.arrayContaining(['shadow-[inset_1px_0_0_#E2E8F0]', 'dark:shadow-[inset_1px_0_0_#222838]']));
    }
  });

  it('sidebar links carry the focus-ring tokens (offset matches the sidebar surface)', () => {
    mockUsePortalAuth.mockReturnValue({ role: 'org_admin', email: 'taylor@example.test', signOut: vi.fn() });
    render(
      <MemoryRouter initialEntries={['/admin/users']}>
        <Sidebar />
      </MemoryRouter>
    );
    const link = screen.getByRole('link', { name: /Users and roles/ });
    expect(classesOf(link)).toEqual(expect.arrayContaining(tokens(FOCUS_RING_ON_SUNKEN_CLASS)));
    expect(FOCUS_RING_ON_SUNKEN_CLASS).toMatch(/dark:focus-visible:ring-offset-\[#0B0F19\]/);
  });
});

describe('item 13: AdminContext toast placement; IdleWarningDialog dark tokens', () => {
  it('the AdminContext toast is not in the bottom-right corner over the pinned ⋯ column', () => {
    let show: ((m: string, t: 'success' | 'error' | 'info') => void) | null = null;
    const Grab: React.FC = () => {
      show = useAdmin().showToast;
      return null;
    };
    vi.useFakeTimers();
    try {
      render(
        <AdminProvider>
          <Grab />
        </AdminProvider>
      );
      act(() => show!('Failed to load patients', 'error'));
      const toast = screen.getByText('Failed to load patients').parentElement as HTMLElement;
      const cls = classesOf(toast);
      expect(cls).not.toContain('right-8');
      expect(cls).toEqual(expect.arrayContaining(['left-1/2', '-translate-x-1/2']));
    } finally {
      vi.useRealTimers();
    }
  });

  it('IdleWarningDialog uses surface and text tokens in dark', () => {
    render(<IdleWarningDialog secondsRemaining={90} onStaySignedIn={() => {}} onSignOut={() => {}} />);
    const dialog = screen.getByRole('alertdialog');
    expect(classesOf(dialog)).toContain('dark:bg-[#10141F]');
    expect(classesOf(screen.getByRole('heading', { name: 'Are you still there?' }))).toContain('dark:text-[#EEF1F8]');
    expect(classesOf(screen.getByText(/For patient privacy/))).toContain('dark:text-[#A6B0C3]');
    expect(classesOf(screen.getByText(/Signing out in/))).toContain('dark:text-[#EEF1F8]');
  });
});

describe('item 14: sidebar fills the viewport height while the page scrolls', () => {
  it('is sticky at the top with the full viewport height', () => {
    mockUsePortalAuth.mockReturnValue({ role: 'org_admin', email: 'taylor@example.test', signOut: vi.fn() });
    render(
      <MemoryRouter initialEntries={['/admin/users']}>
        <Sidebar />
      </MemoryRouter>
    );
    const cls = classesOf(screen.getByRole('navigation', { name: 'Main' }));
    expect(cls).toEqual(expect.arrayContaining(['sticky', 'top-0', 'h-screen']));
  });
});


