// @vitest-environment jsdom
// TC-019 M3/M4 (Ava must-fix): Button.tsx and the users-table "···" trigger
// still used the old 2px #2C5CF2 ring instead of the focus.ring token. See
// tests/admin-shell/focus-ring-token.test.tsx for the token itself already
// applied to TextInput/SelectField/SearchField/TextField.
import React from 'react';
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import Button from '../../components/admin-auth/Button';
import RowActionsMenu from '../../components/ui/RowActionsMenu';
import { FOCUS_RING_CLASS } from '../../components/ui/focusRing';

const FOCUS_RING_TOKENS = FOCUS_RING_CLASS.split(/\s+/).filter(Boolean);

describe('Button focus ring token (Ava M3)', () => {
  it('carries every FOCUS_RING_CLASS token and not the old 2C5CF2 ring', () => {
    render(<Button>Invite user</Button>);
    const btn = screen.getByRole('button', { name: 'Invite user' });
    for (const token of FOCUS_RING_TOKENS) {
      expect(btn.className).toContain(token);
    }
    expect(btn.className).not.toMatch(/ring-\[#2C5CF2\]/);
    expect(btn.className).not.toMatch(/focus-visible:ring-2\b/);
  });
});

describe('Row actions "···" trigger focus ring token (Ava M4)', () => {
  it('carries every FOCUS_RING_CLASS token', () => {
    render(<RowActionsMenu email="alex@example.test" items={[{ label: 'Deactivate', onClick: () => {} }]} />);
    const trigger = screen.getByRole('button', { name: /More actions/ });
    for (const token of FOCUS_RING_TOKENS) {
      expect(trigger.className).toContain(token);
    }
    expect(trigger.className).not.toMatch(/ring-\[#2C5CF2\]/);
  });
});
