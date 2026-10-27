// @vitest-environment jsdom
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import RequireSession from '../../components/admin-shell/RequireSession';
import { usePortalAuth } from '../../contexts/PortalAuthContext';

vi.mock('../../contexts/PortalAuthContext', async () => {
  const actual = await vi.importActual<typeof import('../../contexts/PortalAuthContext')>(
    '../../contexts/PortalAuthContext'
  );
  return { ...actual, usePortalAuth: vi.fn() };
});

const mockedUsePortalAuth = vi.mocked(usePortalAuth);

function renderAtAdmin(auth: Partial<ReturnType<typeof usePortalAuth>>) {
  mockedUsePortalAuth.mockReturnValue({
    status: 'aal1',
    email: 'doc@example.test',
    role: 'physician',
    orgId: 'org-1',
    hasFactor: true,
    endedByAdmin: false,
    refresh: vi.fn(),
    signIn: vi.fn(),
    requestPasswordReset: vi.fn(),
    acceptInvite: vi.fn(),
    enrollTotp: vi.fn(),
    verifyTotpEnrollment: vi.fn(),
    challengeTotp: vi.fn(),
    verifyTotpChallenge: vi.fn(),
    verifyRecoveryCode: vi.fn(),
    generateRecoveryCodes: vi.fn(),
    signOut: vi.fn(),
    ...auth,
  } as unknown as ReturnType<typeof usePortalAuth>);

  return render(
    <MemoryRouter initialEntries={['/admin']}>
      <Routes>
        <Route
          path="/admin"
          element={
            <RequireSession>
              <div>ADMIN SHELL</div>
            </RequireSession>
          }
        />
        <Route path="/admin/login" element={<div>LOGIN SCREEN</div>} />
        <Route path="/admin/2fa/challenge" element={<div>CHALLENGE SCREEN</div>} />
        <Route path="/admin/2fa/setup" element={<div>SETUP SCREEN</div>} />
      </Routes>
    </MemoryRouter>
  );
}

describe('RequireSession aal1 bounce (H-E2E-1)', () => {
  beforeEach(() => mockedUsePortalAuth.mockReset());

  it('sends aal1 + hasFactor to /admin/2fa/challenge, not login', () => {
    renderAtAdmin({ status: 'aal1', hasFactor: true });
    expect(screen.getByText('CHALLENGE SCREEN')).toBeInTheDocument();
    expect(screen.queryByText('LOGIN SCREEN')).not.toBeInTheDocument();
    expect(screen.queryByText('ADMIN SHELL')).not.toBeInTheDocument();
  });

  it('sends aal1 without factor to /admin/2fa/setup, not login', () => {
    renderAtAdmin({ status: 'aal1', hasFactor: false });
    expect(screen.getByText('SETUP SCREEN')).toBeInTheDocument();
    expect(screen.queryByText('LOGIN SCREEN')).not.toBeInTheDocument();
  });

  it('allows aal2 into the admin shell', () => {
    renderAtAdmin({ status: 'aal2', hasFactor: true });
    expect(screen.getByText('ADMIN SHELL')).toBeInTheDocument();
  });
});
