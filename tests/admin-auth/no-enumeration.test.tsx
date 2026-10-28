// @vitest-environment jsdom
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor, cleanup } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import SignIn from '../../pages/admin/SignIn';
import { usePortalAuth } from '../../contexts/PortalAuthContext';

vi.mock('../../contexts/PortalAuthContext', async () => {
  const actual = await vi.importActual<typeof import('../../contexts/PortalAuthContext')>(
    '../../contexts/PortalAuthContext'
  );
  return { ...actual, usePortalAuth: vi.fn() };
});

const mockedUsePortalAuth = vi.mocked(usePortalAuth);

// OVERRIDES #5: the sign-in error/network/reset-sent responses must render
// byte-identical copy whether the underlying account is real (e.g. a locked
// account + wrong password) or unknown - the server already collapses both
// to the same `invalid_credentials` outcome; this test proves the UI layer
// doesn't reintroduce a distinguishing signal on top of that.
async function renderAndSubmit(email: string, signInResult: { ok: boolean; error?: string }) {
  cleanup();
  const signIn = vi.fn().mockResolvedValue(signInResult);
  mockedUsePortalAuth.mockReturnValue({
    status: 'signed_out',
    email: null,
    role: null,
    orgId: null,
    hasFactor: false,
    refresh: vi.fn(),
    signIn,
    requestPasswordReset: vi.fn(),
    acceptInvite: vi.fn(),
    enrollTotp: vi.fn(),
    verifyTotpEnrollment: vi.fn(),
    challengeTotp: vi.fn(),
    verifyTotpChallenge: vi.fn(),
    verifyRecoveryCode: vi.fn(),
    generateRecoveryCodes: vi.fn(),
    signOut: vi.fn(),
  } as unknown as ReturnType<typeof usePortalAuth>);

  render(
    <MemoryRouter>
      <SignIn />
    </MemoryRouter>
  );
  fireEvent.change(screen.getByLabelText('Work email'), { target: { value: email } });
  fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'wrong-password' } });
  fireEvent.click(screen.getByRole('button', { name: 'Continue' }));
  await waitFor(() => screen.getByRole('alert'));
  return screen.getByRole('alert').textContent;
}

describe('01-sign-in: no account enumeration', () => {
  beforeEach(() => {
    mockedUsePortalAuth.mockReset();
  });

  it('renders byte-identical error copy for a real (locked) account and an unknown email', async () => {
    const realAccountText = await renderAndSubmit('morgan.ellis@example.test', {
      ok: false,
      error: 'invalid_credentials',
    });
    const unknownEmailText = await renderAndSubmit('nobody-at-all@example.test', {
      ok: false,
      error: 'invalid_credentials',
    });
    expect(realAccountText).toBe(unknownEmailText);
    expect(realAccountText).toBe("That email and password don't match. Check both and try again.");
  });

  it('renders the generic network-error copy identically regardless of email', async () => {
    const a = await renderAndSubmit('morgan.ellis@example.test', { ok: false, error: 'network_error' });
    const b = await renderAndSubmit('nobody-at-all@example.test', { ok: false, error: 'network_error' });
    expect(a).toBe(b);
  });
});
