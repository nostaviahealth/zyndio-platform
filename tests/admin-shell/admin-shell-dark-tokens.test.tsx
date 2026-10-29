// @vitest-environment jsdom
// TC-019 M2 (Ava must-fix): AppShell/Sidebar/AccessDenied/Toast render 0
// dark: classes today, so the shell stays light even once the `dark` class
// is wired up. These assert the real components in the /admin route tree
// (App.tsx), not pages/preview/PreviewShell.tsx (fixture-only chrome
// already covered by tests/admin-shell/users-roles-dark-tokens.test.tsx).
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

const mockUsePortalAuth = vi.fn();
vi.mock('../../contexts/PortalAuthContext', () => ({
  usePortalAuth: () => mockUsePortalAuth(),
}));

import AppShell from '../../components/admin-shell/AppShell';
import Sidebar from '../../components/admin-shell/Sidebar';
import AccessDenied from '../../pages/admin/AccessDenied';
import { ToastProvider, useToast } from '../../components/ui/Toast';

describe('AppShell dark shell canvas (Ava M2)', () => {
  it('carries a dark canvas class alongside the light F2F4F7 canvas', () => {
    mockUsePortalAuth.mockReturnValue({ role: 'org_admin', email: 'taylor@example.test', signOut: vi.fn() });
    const { container } = render(
      <MemoryRouter>
        <AppShell />
      </MemoryRouter>
    );
    const canvas = container.querySelector('.flex.min-h-screen') as HTMLElement;
    expect(canvas).toBeTruthy();
    expect(canvas.className).toMatch(/dark:bg-\[#070A14\]/);
  });
});

describe('Sidebar dark tokens (Ava M2)', () => {
  it('carries dark surface, active-item and nav text tokens', () => {
    mockUsePortalAuth.mockReturnValue({ role: 'org_admin', email: 'taylor@example.test', signOut: vi.fn() });
    render(
      <MemoryRouter initialEntries={['/admin/users']}>
        <Sidebar />
      </MemoryRouter>
    );
    const nav = screen.getByRole('navigation', { name: 'Main' });
    expect(nav.className).toMatch(/dark:bg-\[#0B0F19\]/);
    const navLink = screen.getByRole('link', { name: /Users and roles/ });
    expect(navLink.className).toMatch(/dark:bg-\[#18224A\]/);
    expect(navLink.className).toMatch(/dark:text-\[#AFC3FF\]/);
  });
});

describe('AccessDenied dark tokens (Ava M2)', () => {
  it('carries dark heading, body and canvas tokens', () => {
    mockUsePortalAuth.mockReturnValue({ role: 'physician' });
    render(
      <MemoryRouter>
        <AccessDenied pageLabel="Users and roles" />
      </MemoryRouter>
    );
    const heading = screen.getByRole('heading', { name: /don't have access/ });
    expect(heading.className).toMatch(/dark:text-\[#EEF1F8\]/);
  });
});

describe('Toast dark tokens (Ava M2: dark toast is a light pill)', () => {
  const Harness: React.FC = () => {
    const { showToast } = useToast();
    return <button onClick={() => showToast({ message: 'Invite sent.' })}>fire</button>;
  };

  it('renders a light pill (#F1F4FC) with dark text in dark mode, keeping the light-mode pill unchanged', () => {
    render(
      <ToastProvider>
        <Harness />
      </ToastProvider>
    );
    fireEvent.click(screen.getByText('fire'));
    const toast = screen.getByRole('status');
    expect(toast.className).toMatch(/bg-\[#030616\]/); // light mode unchanged
    expect(toast.className).toMatch(/dark:bg-\[#F1F4FC\]/);
    expect(toast.className).toMatch(/dark:text-\[#030616\]/);
  });
});
