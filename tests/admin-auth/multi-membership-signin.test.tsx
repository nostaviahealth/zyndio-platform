// @vitest-environment jsdom
// TC-018 (29 Oct, Clara #16): a staff member with TWO active clinic
// memberships fails to sign in. load()'s org_members lookup used
// .maybeSingle(), which (mirrored here exactly as real PostgREST behaves)
// returns an error - not a thrown exception, not the first row - when more
// than one row matches. signIn() treats any failed/empty lookup as "no
// ACTIVE staff membership" and refuses with the generic wrong-password
// message, so a legitimate multi-clinic staff member can never sign in.
// Fix: resolve a default (earliest-created) membership instead of erroring
// out; a clinic picker across all active memberships is a follow-up.
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, waitFor, act } from '@testing-library/react';
import { PortalAuthProvider, usePortalAuth } from '../../contexts/PortalAuthContext';

type MemberRow = { user_id: string; org_id: string; role: string; status: string; created_at: string };

const fake = vi.hoisted(() => ({
  session: null as null | { user: { id: string; email: string } },
  members: [] as { user_id: string; org_id: string; role: string; status: string; created_at: string }[],
  signOut: vi.fn(),
  nextUser: { id: 'u-1', email: 'fictional.staff@example.test' },
}));

vi.mock('../../lib/supabase', () => {
  // Mirrors real PostgREST: .maybeSingle() errors (doesn't throw, doesn't
  // just return the first row) when more than one row matches; an
  // unterminated query (.order() then awaited directly) resolves an array.
  const from = (table: string) => {
    const filters: [string, unknown][] = [];
    let orderCol: string | null = null;
    let orderAscending = true;
    const matchingRows = () =>
      fake.members.filter((r) =>
        filters.every(([c, v]) => (r as unknown as Record<string, unknown>)[c] === v)
      );
    const builder = {
      select: () => builder,
      eq: (col: string, val: unknown) => {
        filters.push([col, val]);
        return builder;
      },
      order: (col: string, opts?: { ascending?: boolean }) => {
        orderCol = col;
        orderAscending = opts?.ascending !== false;
        return builder;
      },
      maybeSingle: async () => {
        if (table !== 'org_members') return { data: null, error: null };
        const rows = matchingRows();
        if (rows.length > 1) {
          return { data: null, error: { code: 'PGRST116', message: 'JSON object requested, multiple (or no) rows returned' } };
        }
        return { data: rows[0] ?? null, error: null };
      },
      then: (resolve: (v: { data: unknown[]; error: null }) => void) => {
        if (table !== 'org_members') {
          resolve({ data: [], error: null });
          return;
        }
        let rows = matchingRows();
        if (orderCol) {
          const col = orderCol;
          rows = [...rows].sort((a, b) => {
            const av = (a as unknown as Record<string, unknown>)[col] as string;
            const bv = (b as unknown as Record<string, unknown>)[col] as string;
            if (av === bv) return 0;
            return (av < bv ? -1 : 1) * (orderAscending ? 1 : -1);
          });
        }
        resolve({ data: rows, error: null });
      },
    };
    return builder;
  };
  return {
    supabase: {
      from,
      auth: {
        getSession: async () => ({ data: { session: fake.session } }),
        signInWithPassword: async () => {
          fake.session = { user: fake.nextUser };
          return { data: {}, error: null };
        },
        signOut: async () => {
          fake.signOut();
          fake.session = null;
          return { error: null };
        },
        onAuthStateChange: () => ({ data: { subscription: { unsubscribe: () => {} } } }),
        mfa: {
          getAuthenticatorAssuranceLevel: async () => ({
            data: fake.session ? { currentLevel: 'aal1', nextLevel: 'aal1' } : { currentLevel: null, nextLevel: null },
          }),
        },
      },
    },
  };
});

let ctx: ReturnType<typeof usePortalAuth> | null = null;
const Probe: React.FC = () => {
  ctx = usePortalAuth();
  return null;
};

async function renderProvider() {
  render(
    <PortalAuthProvider>
      <Probe />
    </PortalAuthProvider>
  );
  await waitFor(() => expect(ctx?.status).toBe('signed_out'));
}

describe('PortalAuth sign-in with two active clinic memberships (TC-018, 29 Oct)', () => {
  beforeEach(() => {
    fake.session = null;
    fake.members = [];
    fake.signOut.mockReset();
    ctx = null;
  });

  it('signs in and resolves a default (earliest-created) membership instead of failing', async () => {
    fake.members = [
      { user_id: 'u-1', org_id: 'org-newer', role: 'physician', status: 'active', created_at: '2026-06-01T00:00:00Z' } as MemberRow,
      { user_id: 'u-1', org_id: 'org-older', role: 'care_coordinator', status: 'active', created_at: '2026-01-01T00:00:00Z' } as MemberRow,
    ];
    await renderProvider();
    let result: Awaited<ReturnType<NonNullable<typeof ctx>['signIn']>> | undefined;
    await act(async () => {
      result = await ctx!.signIn('fictional.staff@example.test', 'Fictional-Pass-1!');
    });
    expect(result).toEqual({ ok: true, hasFactor: false });
    expect(fake.signOut).not.toHaveBeenCalled();
    expect(ctx!.role).toBe('care_coordinator');
    expect(ctx!.orgId).toBe('org-older');
  });
});
