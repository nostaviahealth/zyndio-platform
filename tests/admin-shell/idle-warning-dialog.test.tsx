// @vitest-environment jsdom
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import IdleWarningDialog from '../../components/admin-shell/IdleWarningDialog';

describe('IdleWarningDialog', () => {
  it('is an alertdialog with the countdown as a non-announcing timer', () => {
    render(
      <IdleWarningDialog secondsRemaining={125} onStaySignedIn={() => {}} onSignOut={() => {}} />
    );
    const dialog = screen.getByRole('alertdialog');
    expect(dialog).toHaveAttribute('aria-modal', 'true');
    expect(dialog).toHaveAttribute('aria-labelledby');
    expect(dialog).toHaveAttribute('aria-describedby');

    const timer = screen.getByRole('timer');
    expect(timer).toHaveAttribute('aria-live', 'off');
    expect(timer).toHaveTextContent('2:05');
  });

  it('puts initial focus on "Stay signed in"', () => {
    render(
      <IdleWarningDialog secondsRemaining={120} onStaySignedIn={() => {}} onSignOut={() => {}} />
    );
    expect(screen.getByRole('button', { name: 'Stay signed in' })).toHaveFocus();
  });

  it('traps Tab focus inside the dialog (wraps last -> first -> last)', async () => {
    const user = userEvent.setup();
    render(
      <IdleWarningDialog secondsRemaining={120} onStaySignedIn={() => {}} onSignOut={() => {}} />
    );
    const stayButton = screen.getByRole('button', { name: 'Stay signed in' });
    const signOutButton = screen.getByRole('button', { name: 'Sign out' });

    // Initial focus is "Stay signed in", the last focusable element in DOM order.
    expect(stayButton).toHaveFocus();
    await user.tab();
    expect(document.activeElement).toBe(signOutButton); // wraps to the first

    await user.tab({ shift: true });
    expect(document.activeElement).toBe(stayButton); // shift+tab wraps back to the last
  });

  it('announces only at the 60s and 30s thresholds via a polite live region', () => {
    const { rerender } = render(
      <IdleWarningDialog secondsRemaining={90} onStaySignedIn={() => {}} onSignOut={() => {}} />
    );
    expect(screen.getByRole('status')).toHaveTextContent('');

    rerender(<IdleWarningDialog secondsRemaining={60} onStaySignedIn={() => {}} onSignOut={() => {}} />);
    expect(screen.getByRole('status')).toHaveTextContent('Signing out in 60 seconds');

    rerender(<IdleWarningDialog secondsRemaining={45} onStaySignedIn={() => {}} onSignOut={() => {}} />);
    expect(screen.getByRole('status')).toHaveTextContent('Signing out in 60 seconds');

    rerender(<IdleWarningDialog secondsRemaining={30} onStaySignedIn={() => {}} onSignOut={() => {}} />);
    expect(screen.getByRole('status')).toHaveTextContent('Signing out in 30 seconds');
  });

  it('calls onStaySignedIn / onSignOut from their buttons', async () => {
    const user = userEvent.setup();
    const onStaySignedIn = vi.fn();
    const onSignOut = vi.fn();
    render(
      <IdleWarningDialog secondsRemaining={120} onStaySignedIn={onStaySignedIn} onSignOut={onSignOut} />
    );
    await user.click(screen.getByRole('button', { name: 'Sign out' }));
    expect(onSignOut).toHaveBeenCalledTimes(1);
    await user.click(screen.getByRole('button', { name: 'Stay signed in' }));
    expect(onStaySignedIn).toHaveBeenCalledTimes(1);
  });
});
