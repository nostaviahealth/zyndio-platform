// @vitest-environment jsdom
// TC-018 (29 Oct, Clara #16): AdminContext.updatePatient/deletePatient still
// write to the removed `profiles` table (createPatient is handled
// separately by the Create Patient add-on, which replaces it with a real
// patients-table-backed flow). These two dead writes must go.
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, waitFor, act } from '@testing-library/react';

const fake = vi.hoisted(() => ({ fromCalls: [] as string[] }));

vi.mock('../../lib/supabase', () => {
  const builder = {
    select: () => builder,
    insert: () => builder,
    update: () => builder,
    delete: () => builder,
    upsert: () => builder,
    eq: () => builder,
    order: () => builder,
    single: async () => ({ data: null, error: { code: '42P01', message: 'relation does not exist' } }),
    then: (resolve: (v: unknown) => void) => resolve({ data: [], error: null }),
  };
  const from = (table: string) => {
    fake.fromCalls.push(table);
    return builder;
  };
  return { supabase: { from } };
});

import { AdminProvider, useAdmin } from '../../contexts/AdminContext';

let ctx: ReturnType<typeof useAdmin> | null = null;
const Probe: React.FC = () => {
  ctx = useAdmin();
  return null;
};

async function renderProvider() {
  render(
    <AdminProvider>
      <Probe />
    </AdminProvider>
  );
  await waitFor(() => expect(ctx).not.toBeNull());
}

beforeEach(() => {
  fake.fromCalls.length = 0;
});

describe('AdminContext no longer touches the removed profiles table', () => {
  it('updatePatient never queries profiles', async () => {
    await renderProvider();
    await act(async () => {
      await ctx!.updatePatient('patient-1', { name: 'Fictional Patient' });
    });
    expect(fake.fromCalls).not.toContain('profiles');
  });

  it('deletePatient never queries profiles', async () => {
    await renderProvider();
    await act(async () => {
      await ctx!.deletePatient('patient-1');
    });
    expect(fake.fromCalls).not.toContain('profiles');
  });
});
