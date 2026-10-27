// @vitest-environment jsdom
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import SignIn from '../../pages/admin/SignIn';
import { usePortalAuth } from '../../contexts/PortalAuthContext';

vi.mock('../../contexts/PortalAuthContext', async () => {
  const actual = await vi.importActual<typeof import('../../contexts/PortalAuthContext')>(
    '../../contexts/PortalAuthContext'
  );
  return { ...actual, usePortalAuth: vi.fn() };
});

const mockedUsePortalAuth = vi.mocked(usePortalAuth);

function baseAuth(overrides: Partial<ReturnType<typeof usePortalAuth>> = {}) {
  return {
    status: 'signed_out',
    email: null,
    role: null,
    orgId: null,
    hasFactor: false,
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
    ...overrides,
  } as unknown as ReturnType<typeof usePortalAuth>;
}

function renderSignIn(signIn: ReturnType<typeof vi.fn>) {
  mockedUsePortalAuth.mockReturnValue(baseAuth({ signIn }));
  return render(
    <MemoryRouter initialEntries={['/admin/login']}>
      <Routes>
        <Route path="/admin/login" element={<SignIn />} />
        <Route path="/admin" element={<div>ADMIN SHELL</div>} />
        <Route path="/admin/2fa/challenge" element={<div>CHALLENGE SCREEN</div>} />
        <Route path="/admin/2fa/setup" element={<div>SETUP SCREEN</div>} />
      </Routes>
    </MemoryRouter>
  );
}

describe('SignIn aal routing (H-E2E-1)', () => {
  beforeEach(() => mockedUsePortalAuth.mockReset());

  it('routes an MFA user (hasFactor) to /admin/2fa/challenge, not /admin', async () => {
    const signIn = vi.fn().mockResolvedValue({ ok: true, hasFactor: true });
    renderSignIn(signIn);
    fireEvent.change(screen.getByLabelText('Work email'), { target: { value: 'doc@example.test' } });
    fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'E2e-Test-Passw0rd!' } });
    fireEvent.click(screen.getByRole('button', { name: 'Continue' }));
    await waitFor(() => expect(screen.getByText('CHALLENGE SCREEN')).toBeInTheDocument());
    expect(screen.queryByText('ADMIN SHELL')).not.toBeInTheDocument();
  });

  it('routes a new user (no factor) to /admin/2fa/setup, not /admin', async () => {
    const signIn = vi.fn().mockResolvedValue({ ok: true, hasFactor: false });
    renderSignIn(signIn);
    fireEvent.change(screen.getByLabelText('Work email'), { target: { value: 'new@example.test' } });
    fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'E2e-Test-Passw0rd!' } });
    fireEvent.click(screen.getByRole('button', { name: 'Continue' }));
    await waitFor(() => expect(screen.getByText('SETUP SCREEN')).toBeInTheDocument());
    expect(screen.queryByText('ADMIN SHELL')).not.toBeInTheDocument();
  });
});
