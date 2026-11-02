// @vitest-environment jsdom
// TC-030 (12): the patient web portal's mock sidebar user must use a FICTIONAL
// name. constants.ts CURRENT_USER previously carried a real person's name
// ("Aditya Singh", "Aditya+Singh" in the avatar URL), which breaks the
// fictional-data-only rule for a white-label app.
//
// Fail-first: on the old constants.ts the "not the real name" assertions below
// go red (CURRENT_USER.name === 'Aditya Singh').
import { describe, it, expect } from 'vitest';
import { CURRENT_USER } from '../../constants';

// The specific real name that used to ship. Kept here (not in app code) only to
// assert it never comes back.
const REAL_NAME = ['Aditya', 'Singh'].join(' ');

describe('TC-030 12: CURRENT_USER demo name is fictional', () => {
  it('is not the real person name that previously shipped', () => {
    expect(CURRENT_USER.name).not.toBe(REAL_NAME);
    expect(CURRENT_USER.name.toLowerCase()).not.toContain('aditya');
  });

  it('is a non-empty, two-word fictional display name', () => {
    expect(CURRENT_USER.name.trim().length).toBeGreaterThan(0);
    expect(CURRENT_USER.name.trim().split(/\s+/).length).toBeGreaterThanOrEqual(2);
  });

  it('the avatar URL no longer encodes the real name', () => {
    expect(CURRENT_USER.avatarUrl.toLowerCase()).not.toContain('aditya');
  });
});
