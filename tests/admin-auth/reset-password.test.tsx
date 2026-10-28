// @vitest-environment jsdom
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import ResetPassword from '../../pages/admin/ResetPassword';
import { usePortalAuth } from '../../contexts/PortalAuthContext';
import { supabase } from '../../lib/supabase';

vi.mock('../../contexts/PortalAuthContext', async () => {
  const actual = await vi.importActual<typeof import('../../contexts/PortalAuthContext')>(
    '../../contexts/PortalAuthContext'
  );
  return { ...actual, usePortalAuth: vi.fn() };
});

vi.mock('../../lib/supabase', () => ({
  supabase: { auth: { signOut: vi.fn().mockResolvedValue({ error: null }) } },
}));

const mockedUsePortalAuth = vi.mocked(usePortalAuth);

function renderReset(status: 'loading' | 'signed_out' | 'aal1' | 'aal2', changePassword: ReturnType<typeof vi.fn>) {
  mockedUsePortalAuth.mockReturnValue({
    status,
    email: null,
    role: null,
    orgId: null,
    hasFactor: false,
    endedByAdmin: false,
    refresh: vi.fn(),
    signIn: vi.fn(),
    requestPasswordReset: vi.fn(),
    acceptInvite: vi.fn(),
    changePassword,
    enrollTotp: vi.fn(),
    verifyTotpEnrollment: vi.fn(),
    challengeTotp: vi.fn(),
    verifyTotpChallenge: vi.fn(),
    verifyRecoveryCode: vi.fn(),
    generateRecoveryCodes: vi.fn(),
    signOut: vi.fn(),
  } as unknown as ReturnType<typeof usePortalAuth>);

  return render(
    <MemoryRouter initialEntries={['/admin/reset-password']}>
      <Routes>
        <Route path="/admin/reset-password" element={<ResetPassword />} />
        <Route path="/admin/login" element={<div>LOGIN SCREEN</div>} />
      </Routes>
    </MemoryRouter>
  );
}

const SUBMIT_LABEL = 'Reset password';
const FIELD_LABEL = 'New password';

function ruleItem(text: string) {
  const el = screen.getByText(text).closest('li');
  if (!el) throw new Error(`no <li> ancestor for "${text}"`);
  return el;
}

describe('01-sign-in/reset-password: rule 7 (same five live rules as invite)', () => {
  beforeEach(() => {
    mockedUsePortalAuth.mockReset();
    vi.mocked(supabase.auth.signOut).mockClear();
  });

  it('shows an expired-link message instead of the form when there is no recovery session', () => {
    renderReset('signed_out', vi.fn());
    expect(screen.getByText('This link is no longer valid')).toBeInTheDocument();
    expect(screen.queryByLabelText(FIELD_LABEL)).not.toBeInTheDocument();
  });

  it('never disables the submit button, even with an empty or short password', () => {
    renderReset('aal1', vi.fn());
    const button = screen.getByRole('button', { name: SUBMIT_LABEL });
    expect(button).toBeEnabled();

    fireEvent.change(screen.getByLabelText(FIELD_LABEL), { target: { value: 'short' } });
    expect(button).toBeEnabled();
  });

  it('on submit with unmet rules, turns them red and returns focus to the password field, without calling changePassword', () => {
    const changePassword = vi.fn();
    renderReset('aal1', changePassword);
    const field = screen.getByLabelText(FIELD_LABEL);

    fireEvent.change(field, { target: { value: 'short' } });
    fireEvent.click(screen.getByRole('button', { name: SUBMIT_LABEL }));

    expect(ruleItem('At least 12 characters')).toHaveClass('text-red-600');
    expect(field).toHaveFocus();
    expect(changePassword).not.toHaveBeenCalled();
  });

  it('shows the exact blocklist error copy, with no "leaked" wording, when change-password rejects a common password', async () => {
    const changePassword = vi.fn().mockResolvedValue({ ok: false, error: 'password_too_common' });
    renderReset('aal1', changePassword);

    fireEvent.change(screen.getByLabelText(FIELD_LABEL), { target: { value: 'Chocolate@123' } });
    fireEvent.click(screen.getByRole('button', { name: SUBMIT_LABEL }));

    await waitFor(() => screen.getByRole('alert'));
    expect(screen.getByRole('alert').textContent).toBe('This password is too common. Choose another one.');
    expect(ruleItem('Not a commonly used password')).toHaveClass('text-red-600');
    expect(document.body.textContent?.toLowerCase()).not.toContain('leaked');
  });

  it('signs out the recovery session and navigates to sign-in once the password is changed', async () => {
    const changePassword = vi.fn().mockResolvedValue({ ok: true });
    renderReset('aal1', changePassword);

    fireEvent.change(screen.getByLabelText(FIELD_LABEL), { target: { value: 'Fictional-Horse-99!' } });
    fireEvent.click(screen.getByRole('button', { name: SUBMIT_LABEL }));

    await waitFor(() => expect(screen.getByText('LOGIN SCREEN')).toBeInTheDocument());
    expect(changePassword).toHaveBeenCalledWith('Fictional-Horse-99!');
    expect(supabase.auth.signOut).toHaveBeenCalled();
  });
});
