// @vitest-environment jsdom
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import ChangePassword from '../../pages/admin/ChangePassword';
import { usePortalAuth } from '../../contexts/PortalAuthContext';

vi.mock('../../contexts/PortalAuthContext', async () => {
  const actual = await vi.importActual<typeof import('../../contexts/PortalAuthContext')>(
    '../../contexts/PortalAuthContext'
  );
  return { ...actual, usePortalAuth: vi.fn() };
});

const mockedUsePortalAuth = vi.mocked(usePortalAuth);

function renderChange(changePassword: ReturnType<typeof vi.fn>) {
  mockedUsePortalAuth.mockReturnValue({
    status: 'aal2',
    email: null,
    role: null,
    orgId: null,
    hasFactor: true,
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
    <MemoryRouter initialEntries={['/admin/change-password']}>
      <Routes>
        <Route path="/admin/change-password" element={<ChangePassword />} />
        <Route path="/admin" element={<div>DASHBOARD</div>} />
      </Routes>
    </MemoryRouter>
  );
}

const SUBMIT_LABEL = 'Change password';
const FIELD_LABEL = 'New password';

function ruleItem(text: string) {
  const el = screen.getByText(text).closest('li');
  if (!el) throw new Error(`no <li> ancestor for "${text}"`);
  return el;
}

describe('change-password: rule 7 (same five live rules as invite)', () => {
  beforeEach(() => {
    mockedUsePortalAuth.mockReset();
  });

  it('never disables the submit button, even with an empty or short password', () => {
    renderChange(vi.fn());
    const button = screen.getByRole('button', { name: SUBMIT_LABEL });
    expect(button).toBeEnabled();

    fireEvent.change(screen.getByLabelText(FIELD_LABEL), { target: { value: 'short' } });
    expect(button).toBeEnabled();
  });

  it('on submit with unmet rules, turns them red and returns focus to the password field, without calling changePassword', () => {
    const changePassword = vi.fn();
    renderChange(changePassword);
    const field = screen.getByLabelText(FIELD_LABEL);

    fireEvent.change(field, { target: { value: 'short' } });
    fireEvent.click(screen.getByRole('button', { name: SUBMIT_LABEL }));

    expect(ruleItem('At least 12 characters')).toHaveClass('text-red-600');
    expect(field).toHaveFocus();
    expect(changePassword).not.toHaveBeenCalled();
  });

  it('shows the exact blocklist error copy, with no "leaked" wording, when change-password rejects a common password', async () => {
    const changePassword = vi.fn().mockResolvedValue({ ok: false, error: 'password_too_common' });
    renderChange(changePassword);

    fireEvent.change(screen.getByLabelText(FIELD_LABEL), { target: { value: 'Chocolate@123' } });
    fireEvent.click(screen.getByRole('button', { name: SUBMIT_LABEL }));

    await waitFor(() => screen.getByRole('alert'));
    expect(screen.getByRole('alert').textContent).toBe('This password is too common. Choose another one.');
    expect(ruleItem('Not a commonly used password')).toHaveClass('text-red-600');
    expect(document.body.textContent?.toLowerCase()).not.toContain('leaked');
  });

  it('shows a confirmation once the password is changed, without navigating away', async () => {
    const changePassword = vi.fn().mockResolvedValue({ ok: true });
    renderChange(changePassword);

    fireEvent.change(screen.getByLabelText(FIELD_LABEL), { target: { value: 'Fictional-Horse-99!' } });
    fireEvent.click(screen.getByRole('button', { name: SUBMIT_LABEL }));

    await waitFor(() => expect(screen.getByText('Password changed')).toBeInTheDocument());
    expect(changePassword).toHaveBeenCalledWith('Fictional-Horse-99!');
    expect(screen.queryByText('DASHBOARD')).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: 'Back to dashboard' }));
    await waitFor(() => expect(screen.getByText('DASHBOARD')).toBeInTheDocument());
  });
});
