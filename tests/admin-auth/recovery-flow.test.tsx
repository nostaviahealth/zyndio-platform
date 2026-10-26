// @vitest-environment jsdom
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import RecoverySignIn from '../../pages/admin/RecoverySignIn';
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
    status: 'aal1',
    email: 'morgan.ellis@example.test',
    role: null,
    orgId: null,
    hasFactor: false,
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

describe('04-recovery-sign-in', () => {
  beforeEach(() => {
    mockedUsePortalAuth.mockReset();
  });

  // Henry's ruling (OVERRIDES #10): a valid recovery code never completes
  // sign-in on its own - it routes straight to 02-2fa-setup for mandatory
  // re-enrolment. 04/low-codes is dropped entirely.
  it('routes a valid recovery code straight to 02-2fa-setup, not to the portal', async () => {
    const verifyRecoveryCode = vi.fn().mockResolvedValue({ ok: true });
    mockedUsePortalAuth.mockReturnValue(baseAuth({ verifyRecoveryCode }));

    render(
      <MemoryRouter initialEntries={['/admin/2fa/recovery']}>
        <Routes>
          <Route path="/admin/2fa/recovery" element={<RecoverySignIn />} />
          <Route path="/admin/2fa/setup" element={<div>SETUP SCREEN</div>} />
        </Routes>
      </MemoryRouter>
    );

    fireEvent.change(screen.getByLabelText('Recovery code'), { target: { value: '7KQ2-M9XD' } });
    fireEvent.click(screen.getByRole('button', { name: 'Sign in' }));

    await waitFor(() => expect(screen.getByText('SETUP SCREEN')).toBeInTheDocument());
    expect(verifyRecoveryCode).toHaveBeenCalledWith('7KQ2-M9XD');
  });

  it('shows the invalid-code error and does not navigate on a wrong code', async () => {
    const verifyRecoveryCode = vi.fn().mockResolvedValue({ ok: false, error: 'wrong_code' });
    mockedUsePortalAuth.mockReturnValue(baseAuth({ verifyRecoveryCode }));

    render(
      <MemoryRouter initialEntries={['/admin/2fa/recovery']}>
        <Routes>
          <Route path="/admin/2fa/recovery" element={<RecoverySignIn />} />
          <Route path="/admin/2fa/setup" element={<div>SETUP SCREEN</div>} />
        </Routes>
      </MemoryRouter>
    );

    fireEvent.change(screen.getByLabelText('Recovery code'), { target: { value: '7KQ2-M9XQ' } });
    fireEvent.click(screen.getByRole('button', { name: 'Sign in' }));

    await waitFor(() => screen.getByRole('alert'));
    expect(screen.getByRole('alert').textContent).toBe(
      "That code isn't valid or has already been used. Wrong codes count toward the 5-attempt limit."
    );
    expect(screen.queryByText('SETUP SCREEN')).not.toBeInTheDocument();
  });
});
