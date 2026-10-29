// @vitest-environment jsdom
// TC-019 fix round, Ava F4 (AA): with a dark OS the sign-in and 2FA pages stay
// light (AuthCard has no dark design yet), but Button switched to its dark
// variant: #7C9CFF on the white card = 2.61:1. Buttons must take the tokens of
// the surface around them, so an AuthCard is a light surface: Tailwind's
// `dark:` variant must not apply inside it, and its native controls use the
// light color-scheme. The real-browser contrast + axe check on sign-in and 2FA
// (dark and light OS) is in scripts/tc019_theme_check.py.
import React from 'react';
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { readFileSync } from 'fs';
import { resolve } from 'path';
import { render, screen } from '@testing-library/react';
import AuthCard from '../../components/admin-auth/AuthCard';
import Button from '../../components/admin-auth/Button';

// The selector Tailwind (CDN, configured in index.html) uses for `dark:`.
function darkVariantSelector(): string {
  const html = readFileSync(resolve(__dirname, '../../index.html'), 'utf8');
  const m = html.match(/darkMode:\s*(\[[^\]]*\]|'[^']*'|"[^"]*")/);
  if (!m) throw new Error('darkMode not found in index.html tailwind.config');
  const raw = m[1];
  if (raw.startsWith("'") || raw.startsWith('"')) {
    const mode = raw.slice(1, -1);
    if (mode === 'class') return ':is(.dark *)';
    throw new Error(`unsupported darkMode ${mode}`);
  }
  // ['variant', '&:is(.dark *)...'] - one selector string
  const parts = raw.match(/'([^']*)'|"([^"]*)"/g)!.map((p) => p.slice(1, -1));
  if (parts[0] !== 'variant' || parts.length !== 2) throw new Error(`unsupported darkMode ${raw}`);
  return parts[1].replace(/&/g, '');
}

function hex(cls: string, prefix: '' | 'dark:', prop: 'bg' | 'text'): string | null {
  for (const token of cls.split(/\s+/)) {
    if (token === `${prefix}${prop}-white`) return '#FFFFFF';
    const m = token.match(new RegExp(`^${prefix}${prop}-\\[#([0-9A-Fa-f]{6})\\]$`));
    if (m) return `#${m[1].toUpperCase()}`;
  }
  return null;
}

function lum(h: string): number {
  const c = [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16) / 255);
  const l = c.map((v) => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4));
  return 0.2126 * l[0] + 0.7152 * l[1] + 0.0722 * l[2];
}
function ratio(a: string, b: string): number {
  const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p);
  return (x + 0.05) / (y + 0.05);
}

// The colours the browser would use for this element, given the dark class.
function effective(el: HTMLElement, prop: 'bg' | 'text'): string {
  const darkApplies = el.matches(darkVariantSelector());
  return (darkApplies && hex(el.className, 'dark:', prop)) || hex(el.className, '', prop)!;
}

const AUTH_CARD_SURFACE = '#FFFFFF'; // AuthCard panel: bg-white

describe('Auth pages keep light button tokens with a dark OS (Ava F4)', () => {
  beforeEach(() => {
    document.documentElement.classList.add('dark');
    document.documentElement.style.colorScheme = 'dark';
  });
  afterEach(() => {
    document.documentElement.classList.remove('dark');
    document.documentElement.style.colorScheme = '';
  });

  for (const label of ['Continue', 'Verify']) {
    it(`${label} on an AuthCard: label >= 4.5:1 and button >= 3:1 against the card`, () => {
      render(
        <AuthCard>
          <Button>{label}</Button>
        </AuthCard>
      );
      const btn = screen.getByRole('button', { name: label });
      expect(btn.matches(darkVariantSelector())).toBe(false);
      const bg = effective(btn, 'bg');
      const fg = effective(btn, 'text');
      expect(ratio(fg, bg)).toBeGreaterThanOrEqual(4.5);
      expect(ratio(bg, AUTH_CARD_SURFACE)).toBeGreaterThanOrEqual(3);
    });
  }

  it('AuthCard uses the light color-scheme for its native controls', () => {
    const { container } = render(
      <AuthCard>
        <input aria-label="Work email" />
      </AuthCard>
    );
    expect((container.firstElementChild as HTMLElement).style.colorScheme).toBe('light');
  });

  it('outside an AuthCard (the dark admin shell) the dark variant still applies', () => {
    render(<Button>Invite user</Button>);
    const btn = screen.getByRole('button', { name: 'Invite user' });
    expect(btn.matches(darkVariantSelector())).toBe(true);
    expect(effective(btn, 'bg')).toBe('#7C9CFF');
  });
});
