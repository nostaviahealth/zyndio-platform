// @vitest-environment jsdom
// TC-018 item 3 round 2 (Clara, PR #24 review): the card calls for a test
// proving an org_admin sign-in writes no "denied" audit entry. Grep across
// supabase/functions and the client finds no audit_log write for a route
// denial anywhere in this codebase (see plan.md) - the only place a denial
// is ever surfaced to the user is AccessDenied.tsx, whose copy claims "This
// attempt was recorded in the audit log." That claim is the one observable
// form a "denied audit entry" takes here, so an org_admin landing on #/admin
// must never reach it. Fail-first: this test goes red if AdminIndex.tsx is
// reverted to its pre-fix behavior (RequireRole(['physician',
// 'care_coordinator','read_only']) wrapping AdminDashboard directly, no role
// dispatch) - see SUMMARY-B.md for the red run.
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';

const mockUsePortalAuth = vi.fn();
vi.mock('../../contexts/PortalAuthContext', () => ({
  usePortalAuth: () => mockUsePortalAuth(),
}));

const mockUseAdmin = vi.fn();
vi.mock('../../contexts/AdminContext', () => ({
  useAdmin: () => mockUseAdmin(),
}));

// Imported after the mocks so AdminIndex and its children (RequireRole,
// AccessDenied, AdminDashboard) resolve to them.
import AdminIndex from '../../components/admin-shell/AdminIndex';

describe('#/admin org_admin sign-in writes no "denied" audit entry (TC-018 item 3 round 2)', () => {
  it('never reaches AccessDenied, so never shows its "recorded in the audit log" claim', () => {
    mockUseAdmin.mockReturnValue({ patients: [], deletePatient: vi.fn(), loading: false });
    mockUsePortalAuth.mockReturnValue({ role: 'org_admin' });
    render(
      <MemoryRouter initialEntries={['/admin']}>
        <Routes>
          <Route path="/admin" element={<AdminIndex />} />
          <Route path="/admin/users" element={<div>USERS AND ROLES PAGE</div>} />
        </Routes>
      </MemoryRouter>
    );
    expect(screen.queryByText("You don't have access to this page")).not.toBeInTheDocument();
    expect(screen.queryByText(/recorded in the audit log/i)).not.toBeInTheDocument();
    expect(screen.getByText('USERS AND ROLES PAGE')).toBeInTheDocument();
  });
});
