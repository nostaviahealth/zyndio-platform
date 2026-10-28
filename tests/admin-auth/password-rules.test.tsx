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

const SUBMIT_LABEL = 'Create password and continue';
const FIELD_LABEL = 'Create a password';

function ruleItem(text: string) {
  const el = screen.getByText(text).closest('li');
  if (!el) throw new Error(`no <li> ancestor for "${text}"`);
  return el;
}

describe('01-sign-in/invite: password rules (M8, Ava 27 Oct)', () => {
  beforeEach(() => {
    mockedUsePortalAuth.mockReset();
  });

  it('never disables the submit button, even with an empty or short password', () => {
    renderInvite(vi.fn());
    const button = screen.getByRole('button', { name: SUBMIT_LABEL });
    expect(button).toBeEnabled();

    fireEvent.change(screen.getByLabelText(FIELD_LABEL), { target: { value: 'short' } });
    expect(button).toBeEnabled();
  });

  it('shows all five rules grey until the password meets them, then green with a check', () => {
    renderInvite(vi.fn());
    const field = screen.getByLabelText(FIELD_LABEL);

    expect(ruleItem('At least 12 characters')).toHaveClass('text-slate-500');
    expect(ruleItem('An uppercase and a lowercase letter')).toHaveClass('text-slate-500');
    expect(ruleItem('A number')).toHaveClass('text-slate-500');
    expect(ruleItem('A symbol, like ! or #')).toHaveClass('text-slate-500');
    expect(ruleItem('Not a commonly used password')).toHaveClass('text-slate-500');

    fireEvent.change(field, { target: { value: 'Fictional-Horse-99!' } });

    expect(ruleItem('At least 12 characters')).toHaveClass('text-emerald-600');
    expect(ruleItem('An uppercase and a lowercase letter')).toHaveClass('text-emerald-600');
    expect(ruleItem('A number')).toHaveClass('text-emerald-600');
    expect(ruleItem('A symbol, like ! or #')).toHaveClass('text-emerald-600');
    // Rule 5 can't be known client-side - still grey even once the other 4 are met.
    expect(ruleItem('Not a commonly used password')).toHaveClass('text-slate-500');
  });

  it('on submit with unmet rules, turns them red and returns focus to the password field, without calling acceptInvite', () => {
    const acceptInvite = vi.fn();
    renderInvite(acceptInvite);
    const field = screen.getByLabelText(FIELD_LABEL);

    fireEvent.change(field, { target: { value: 'short' } });
    fireEvent.click(screen.getByRole('button', { name: SUBMIT_LABEL }));

    expect(ruleItem('At least 12 characters')).toHaveClass('text-red-600');
    expect(ruleItem('An uppercase and a lowercase letter')).toHaveClass('text-red-600');
    expect(ruleItem('A number')).toHaveClass('text-red-600');
    expect(ruleItem('A symbol, like ! or #')).toHaveClass('text-red-600');
    expect(field).toHaveFocus();
    expect(acceptInvite).not.toHaveBeenCalled();
  });

  it('shows the exact blocklist error copy, with no "leaked" wording, when accept-invite rejects a common password', async () => {
    const acceptInvite = vi.fn().mockResolvedValue({ ok: false, error: 'password_too_common' });
    renderInvite(acceptInvite);

    fireEvent.change(screen.getByLabelText(FIELD_LABEL), {
      target: { value: 'Chocolate@123' },
    });
    fireEvent.click(screen.getByRole('button', { name: SUBMIT_LABEL }));

    await waitFor(() => screen.getByRole('alert'));
    expect(screen.getByRole('alert').textContent).toBe('This password is too common. Choose another one.');
    expect(ruleItem('Not a commonly used password')).toHaveClass('text-red-600');
    expect(screen.queryByText('LOGIN SCREEN')).not.toBeInTheDocument();
    expect(document.body.textContent?.toLowerCase()).not.toContain('leaked');
  });

  it('navigates to sign-in once the invite is accepted with a password that meets every rule', async () => {
    const acceptInvite = vi.fn().mockResolvedValue({ ok: true });
    renderInvite(acceptInvite);

    fireEvent.change(screen.getByLabelText(FIELD_LABEL), {
      target: { value: 'Fictional-Horse-99!' },
    });
    fireEvent.click(screen.getByRole('button', { name: SUBMIT_LABEL }));

    await waitFor(() => expect(screen.getByText('LOGIN SCREEN')).toBeInTheDocument());
    expect(acceptInvite).toHaveBeenCalledWith('sometoken', 'Fictional-Horse-99!');
  });
});
