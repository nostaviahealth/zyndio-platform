// @vitest-environment jsdom
// TC-018 (29 Oct, Clara #16): the `profiles` table no longer exists (see
// AdminContext.tsx's already-removed mount-time fetch, TC-022 #3). This
// card asks for the same removal in AuthContext (admin-role lookup) and
// UserContext (patient profile fetch/create) - neither must ever query it,
// through a page load, a sign-in, or a forced sign-out/back-in cycle.
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, waitFor, act } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

const fake = vi.hoisted(() => ({
  session: { user: { id: 'u-1', email: 'fictional.patient@example.test', user_metadata: {} } } as
    | { user: { id: string; email: string; user_metadata: Record<string, unknown> } }
    | null,
  fromCalls: [] as string[],
}));

vi.mock('../../lib/supabase', () => {
  const builder = {
    select: () => builder,
    insert: () => builder,
    eq: () => builder,
    order: () => builder,
    limit: () => builder,
    single: async () => ({ data: null, error: { code: '42P01', message: 'relation does not exist' } }),
    maybeSingle: async () => ({ data: null, error: { code: '42P01', message: 'relation does not exist' } }),
    then: (resolve: (v: unknown) => void) => resolve({ data: [], error: null }),
  };
  const from = (table: string) => {
    fake.fromCalls.push(table);
    return builder;
  };
  return {
    supabase: {
      from,
      auth: {
        getSession: async () => ({ data: { session: fake.session } }),
        signInWithPassword: async () => ({ data: fake.session, error: null }),
        signOut: async () => ({ error: null }),
        onAuthStateChange: () => ({ data: { subscription: { unsubscribe: () => {} } } }),
      },
    },
  };
});

import { AuthProvider, useAuth } from '../../contexts/AuthContext';
import { UserProvider, useUser } from '../../contexts/UserContext';

let authCtx: ReturnType<typeof useAuth> | null = null;
let userCtx: ReturnType<typeof useUser> | null = null;
const Probe: React.FC = () => {
  authCtx = useAuth();
  userCtx = useUser();
  return null;
};

async function renderProviders() {
  render(
    <MemoryRouter>
      <AuthProvider>
        <UserProvider>
          <Probe />
        </UserProvider>
      </AuthProvider>
    </MemoryRouter>
  );
  await waitFor(() => expect(authCtx?.loading).toBe(false));
  await waitFor(() => expect(userCtx?.loading).toBe(false));
}

beforeEach(() => {
  fake.fromCalls.length = 0;
});

describe('legacy AuthContext/UserContext no longer touch the removed profiles table', () => {
  it('never queries profiles on initial load (session restore + patient profile init)', async () => {
    await renderProviders();
    expect(fake.fromCalls).not.toContain('profiles');
  });

  it('never queries profiles during signIn (admin-role lookup removed)', async () => {
    await renderProviders();
    await act(async () => {
      await authCtx!.signIn('fictional.patient@example.test', 'Fictional-Pass-1!');
    });
    expect(fake.fromCalls).not.toContain('profiles');
  });
});
