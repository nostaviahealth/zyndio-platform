// @vitest-environment jsdom
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import AcceptInvite from '../../pages/admin/AcceptInvite';
import { usePortalAuth } from '../../contexts/PortalAuthContext';

vi.mock('../../contexts/PortalAuthContext', async () => {
  const actual = await vi.importActual<typeof import('../../contexts/PortalAuthContext')>(
    '../../contexts/PortalAuthContext'
  );
  return { ...actual, usePortalAuth: vi.fn() };
});

const mockedUsePortalAuth = vi.mocked(usePortalAuth);

function renderInvite(acceptInvite: ReturnType<typeof vi.fn>) {
  mockedUsePortalAuth.mockReturnValue({
    status: 'signed_out',
    email: null,
    role: null,
    orgId: null,
    hasFactor: false,
    refresh: vi.fn(),
    signIn: vi.fn(),
    requestPasswordReset: vi.fn(),
    acceptInvite,
    enrollTotp: vi.fn(),
    verifyTotpEnrollment: vi.fn(),
    challengeTotp: vi.fn(),
    verifyTotpChallenge: vi.fn(),
    verifyRecoveryCode: vi.fn(),
    generateRecoveryCodes: vi.fn(),
    signOut: vi.fn(),
  } as unknown as ReturnType<typeof usePortalAuth>);

  return render(
    <MemoryRouter initialEntries={['/admin/invite/sometoken']}>
      <Routes>
        <Route path="/admin/invite/:token" element={<AcceptInvite />} />
        <Route path="/admin/login" element={<div>LOGIN SCREEN</div>} />
      </Routes>
    </MemoryRouter>
  );
}

describe('01-sign-in/invite: password rules', () => {
  beforeEach(() => {
    mockedUsePortalAuth.mockReset();
  });

  it('disables submit until the password is at least 12 characters', () => {
    renderInvite(vi.fn());
    const button = screen.getByRole('button', { name: 'Create password and continue' });
    expect(button).toBeDisabled();

    fireEvent.change(screen.getByLabelText('Create a password'), { target: { value: 'short' } });
    expect(button).toBeDisabled();

    fireEvent.change(screen.getByLabelText('Create a password'), {
      target: { value: 'twelve-chars-plus' },
    });
    expect(button).toBeEnabled();
  });

  // OVERRIDES #13: the blocklist check is server side; the UI must surface
  // the exact copy-deck wording, not invent its own.
  it('shows the exact blocklist error copy when accept-invite rejects a common password', async () => {
    const acceptInvite = vi.fn().mockResolvedValue({ ok: false, error: 'password_too_common' });
    renderInvite(acceptInvite);

    fireEvent.change(screen.getByLabelText('Create a password'), {
      target: { value: 'password12345' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Create password and continue' }));

    await waitFor(() => screen.getByRole('alert'));
    expect(screen.getByRole('alert').textContent).toBe('This password is too common. Choose another one.');
    expect(screen.queryByText('LOGIN SCREEN')).not.toBeInTheDocument();
  });

  it('navigates to sign-in once the invite is accepted', async () => {
    const acceptInvite = vi.fn().mockResolvedValue({ ok: true });
    renderInvite(acceptInvite);

    fireEvent.change(screen.getByLabelText('Create a password'), {
      target: { value: 'twelve-chars-plus' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Create password and continue' }));

    await waitFor(() => expect(screen.getByText('LOGIN SCREEN')).toBeInTheDocument());
    expect(acceptInvite).toHaveBeenCalledWith('sometoken', 'twelve-chars-plus');
  });
});
