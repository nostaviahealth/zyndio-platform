// @vitest-environment jsdom
// TC-022 item 1 (Clara, PR #11 review): sign-in must be refused when the
// account has no ACTIVE staff membership - a deactivated staff member, or a
// patient account (no org_members row) trying the staff portal. The refusal
// uses the same generic message as a wrong password (OVERRIDES #5), and the
// half-open session is signed out so nothing can continue to 2FA setup.
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, waitFor, act } from '@testing-library/react';
import { PortalAuthProvider, usePortalAuth } from '../../contexts/PortalAuthContext';

type MemberRow = { user_id: string; org_id: string; role: string; status: string };

const fake = vi.hoisted(() => ({
  session: null as null | { user: { id: string; email: string } },
  members: [] as { user_id: string; org_id: string; role: string; status: string }[],
  signOut: vi.fn(),
  nextUser: { id: 'u-1', email: 'fictional.staff@example.test' },
}));

vi.mock('../../lib/supabase', () => {
  // Minimal PostgREST-style builder: every .eq() narrows the fixture rows,
  // so a query that forgets a filter sees rows it shouldn't. .order() then
  // awaiting directly (no .maybeSingle()/.single()) resolves an array, as
  // load() now does (TC-018 29 Oct: supports 2+ active memberships).
  const from = (table: string) => {
    const filters: [string, unknown][] = [];
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
      maybeSingle: async () => {
        if (table !== 'org_members') return { data: null, error: null };
        return { data: matchingRows()[0] ?? null, error: null };
      },
      order: () => builder,
      then: (resolve: (v: { data: unknown[]; error: null }) => void) => {
        resolve({ data: table === 'org_members' ? matchingRows() : [], error: null });
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

describe('PortalAuth sign-in needs an ACTIVE staff membership (TC-022 #1)', () => {
  beforeEach(() => {
    fake.session = null;
    fake.members = [];
    fake.signOut.mockReset();
    ctx = null;
  });

  it('refuses a deactivated staff member with the generic error and signs the session out', async () => {
    fake.members = [{ user_id: 'u-1', org_id: 'org-1', role: 'physician', status: 'deactivated' } as MemberRow];
    await renderProvider();
    let result: Awaited<ReturnType<NonNullable<typeof ctx>['signIn']>> | undefined;
    await act(async () => {
      result = await ctx!.signIn('fictional.staff@example.test', 'Fictional-Pass-1!');
    });
    expect(result).toEqual({ ok: false, error: 'invalid_credentials' });
    expect(fake.signOut).toHaveBeenCalled();
    expect(ctx!.status).toBe('signed_out');
    expect(ctx!.role).toBeNull();
    // A sign-in refusal is not "ended by admin".
    expect(ctx!.endedByAdmin).toBe(false);
  });

  it('refuses a patient account (no staff membership) the same way', async () => {
    fake.members = [];
    await renderProvider();
    let result: Awaited<ReturnType<NonNullable<typeof ctx>['signIn']>> | undefined;
    await act(async () => {
      result = await ctx!.signIn('fictional.patient@example.test', 'Fictional-Pass-1!');
    });
    expect(result).toEqual({ ok: false, error: 'invalid_credentials' });
    expect(fake.signOut).toHaveBeenCalled();
    expect(ctx!.status).toBe('signed_out');
  });

  it('still signs in an active staff member and exposes their role', async () => {
    fake.members = [{ user_id: 'u-1', org_id: 'org-1', role: 'physician', status: 'active' }];
    await renderProvider();
    let result: Awaited<ReturnType<NonNullable<typeof ctx>['signIn']>> | undefined;
    await act(async () => {
      result = await ctx!.signIn('fictional.staff@example.test', 'Fictional-Pass-1!');
    });
    expect(result).toEqual({ ok: true, hasFactor: false });
    expect(fake.signOut).not.toHaveBeenCalled();
    expect(ctx!.role).toBe('physician');
  });

  it('does not expose a role from a deactivated row on an existing session (refresh filter)', async () => {
    fake.session = { user: fake.nextUser };
    fake.members = [{ user_id: 'u-1', org_id: 'org-1', role: 'org_admin', status: 'deactivated' }];
    render(
      <PortalAuthProvider>
        <Probe />
      </PortalAuthProvider>
    );
    await waitFor(() => expect(ctx?.status).toBe('aal1'));
    expect(ctx!.role).toBeNull();
    expect(ctx!.orgId).toBeNull();
  });
});
