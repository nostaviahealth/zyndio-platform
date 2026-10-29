// @vitest-environment jsdom
// TC-022 item 3 (Clara, PR #11 review): AdminProvider wraps every route,
// including sign-in, 2FA and not-found. It used to fetch the removed
// `profiles` table on mount, which failed and showed a "Failed to load
// patients" toast on those pages. It must not query `profiles` at all.
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';

const tablesQueried = vi.hoisted(() => [] as string[]);

vi.mock('../../lib/supabase', () => {
  const removedTableError = { message: 'relation "public.profiles" does not exist', code: '42P01' };
  const from = (table: string) => {
    tablesQueried.push(table);
    const result =
      table === 'profiles' ? { data: null, error: removedTableError } : { data: [], error: null };
    const builder: Record<string, unknown> = {};
    for (const m of ['select', 'eq', 'order', 'insert', 'update', 'delete', 'upsert', 'single']) {
      builder[m] = () => builder;
    }
    builder.then = (resolve: (v: unknown) => unknown) => Promise.resolve(result).then(resolve);
    return builder;
  };
  return { supabase: { from } };
});

import { AdminProvider } from '../../contexts/AdminContext';

describe('AdminProvider does not touch the removed profiles table (TC-022 #3)', () => {
  it('never queries profiles on mount and shows no "Failed to load patients" toast', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    render(
      <AdminProvider>
        <h1>Sign in to the care portal</h1>
      </AdminProvider>
    );
    // Let the mount effects (and any rejected fetch) settle.
    await waitFor(() => expect(tablesQueried.length).toBeGreaterThanOrEqual(0));
    await new Promise((r) => setTimeout(r, 50));
    expect(tablesQueried).not.toContain('profiles');
    expect(screen.queryByText('Failed to load patients')).not.toBeInTheDocument();
  });
});
