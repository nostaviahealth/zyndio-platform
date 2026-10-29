// @vitest-environment jsdom
// TC-019 M1/M6: the real app must set `dark` + `color-scheme` from
// prefers-color-scheme before first paint and keep it live. lib/theme.ts
// holds the logic shared by the inline index.html bootstrap script and the
// React app (index.tsx), so it's covered here instead of only in the
// real-browser check.
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { readFileSync } from 'fs';
import { resolve } from 'path';
import { applySystemTheme, watchSystemTheme } from '../../lib/theme';

describe('applySystemTheme', () => {
  let root: HTMLElement;

  beforeEach(() => {
    root = document.createElement('html');
    root.className = 'some-other-class';
  });

  it('adds the dark class and dark color-scheme when isDark is true', () => {
    applySystemTheme(root, true);
    expect(root.classList.contains('dark')).toBe(true);
    expect(root.style.colorScheme).toBe('dark');
    expect(root.classList.contains('some-other-class')).toBe(true);
  });

  it('removes the dark class and sets light color-scheme when isDark is false', () => {
    root.classList.add('dark');
    root.style.colorScheme = 'dark';
    applySystemTheme(root, false);
    expect(root.classList.contains('dark')).toBe(false);
    expect(root.style.colorScheme).toBe('light');
  });
});

describe('watchSystemTheme', () => {
  function fakeWindow(initialMatches: boolean) {
    let changeHandler: ((e: { matches: boolean }) => void) | null = null;
    const mql = {
      matches: initialMatches,
      addEventListener: vi.fn((event: string, handler: (e: { matches: boolean }) => void) => {
        if (event === 'change') changeHandler = handler;
      }),
      removeEventListener: vi.fn(),
    };
    const win = {
      matchMedia: vi.fn().mockReturnValue(mql),
    };
    return { win, mql, fire: (matches: boolean) => changeHandler?.({ matches }) };
  }

  it('applies the initial scheme and queries prefers-color-scheme: dark', () => {
    const { win, mql } = fakeWindow(true);
    const root = document.createElement('html');
    watchSystemTheme(win as unknown as Window, root);
    expect(win.matchMedia).toHaveBeenCalledWith('(prefers-color-scheme: dark)');
    expect(root.classList.contains('dark')).toBe(true);
    expect(mql.addEventListener).toHaveBeenCalledWith('change', expect.any(Function));
  });

  it('flips the class live when the change event fires', () => {
    const { win, fire } = fakeWindow(false);
    const root = document.createElement('html');
    watchSystemTheme(win as unknown as Window, root);
    expect(root.classList.contains('dark')).toBe(false);
    fire(true);
    expect(root.classList.contains('dark')).toBe(true);
    expect(root.style.colorScheme).toBe('dark');
    fire(false);
    expect(root.classList.contains('dark')).toBe(false);
    expect(root.style.colorScheme).toBe('light');
  });
});

describe('index.html inline head bootstrap (M1: no flash of light theme)', () => {
  const html = readFileSync(resolve(__dirname, '../../index.html'), 'utf-8');

  it('has an inline <head> script that toggles dark/color-scheme from prefers-color-scheme', () => {
    const headMatch = html.match(/<head>([\s\S]*?)<\/head>/);
    expect(headMatch).toBeTruthy();
    const head = headMatch![1];

    const scripts = [...head.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/g)];
    const inlineBootstrap = scripts.find(
      ([, attrs, body]) => !/\bsrc=/.test(attrs) && /prefers-color-scheme/.test(body)
    );
    expect(inlineBootstrap).toBeTruthy();
    const [, , body] = inlineBootstrap!;
    expect(body).toMatch(/classList/);
    expect(body).toMatch(/colorScheme/);
    expect(body).toMatch(/addEventListener\(['"]change['"]/);

    // Must run before the module script that boots React, so there's no
    // frame of light theme before React mounts.
    const moduleScriptIndex = head.indexOf('index.tsx');
    const inlineScriptIndex = head.indexOf(inlineBootstrap![0]);
    expect(inlineScriptIndex).toBeGreaterThan(-1);
    expect(moduleScriptIndex).toBeGreaterThan(-1);
    expect(inlineScriptIndex).toBeLessThan(moduleScriptIndex);
  });
});
