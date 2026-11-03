// @vitest-environment jsdom
// TC-030 item 8 (Henry, 2 Nov 2026 12:24; Clara PR #26 M2): creating a patient
// is a care_coordinator-only action. PR #26 gated the "New Patient" button, but
// the card asks for a web test that fails if a physician gets the create PAGE
// back. Two guards:
//   1. Static: App.tsx's `patients/create` route must wrap CreatePatient in
//      RequireRole gated to care_coordinator only (no physician/read_only).
//      Fails if anyone widens that route's roles back to include 'physician'.
//   2. Behavioural: the real RequireRole with roles={['care_coordinator']}
//      renders the child for a coordinator and the access-denied page for a
//      physician - so the gate value the route uses actually excludes
//      physicians.
import React from 'react';
import fs from 'node:fs';
import path from 'node:path';
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

const mockUsePortalAuth = vi.fn();
vi.mock('../../contexts/PortalAuthContext', () => ({
  usePortalAuth: () => mockUsePortalAuth(),
}));

import RequireRole from '../../components/admin-shell/RequireRole';

describe('TC-030 item 8: /admin/patients/create is care_coordinator only', () => {
  it('App.tsx gates the create route to care_coordinator only (not physician)', () => {
    const app = fs.readFileSync(path.resolve(__dirname, '../../App.tsx'), 'utf8');
    // Isolate the `patients/create` <Route ...> ... </Route> block so the match
    // cannot accidentally pick up a sibling route's RequireRole.
    const block = app.match(/path="patients\/create"[\s\S]*?<\/Route>/);
    expect(block, 'patients/create route not found in App.tsx').not.toBeNull();
    const roles = block![0].match(/<RequireRole\s+roles=\{(\[[^\]]*\])\}/);
    expect(roles, 'create route is not wrapped in RequireRole').not.toBeNull();
    const list = roles![1];
    expect(list).toContain('care_coordinator');
    expect(list).not.toContain('physician');
    expect(list).not.toContain('read_only');
    expect(list).not.toContain('org_admin');
  });

  it('RequireRole(care_coordinator) renders the page for a coordinator', () => {
    mockUsePortalAuth.mockReturnValue({ role: 'care_coordinator' });
    render(
      <MemoryRouter>
        <RequireRole roles={['care_coordinator']}>
          <div>CREATE PATIENT PAGE</div>
        </RequireRole>
      </MemoryRouter>
    );
    expect(screen.getByText('CREATE PATIENT PAGE')).toBeInTheDocument();
  });

  it.each(['physician', 'read_only', 'org_admin'])(
    'RequireRole(care_coordinator) denies %s the create page',
    (role) => {
      mockUsePortalAuth.mockReturnValue({ role });
      render(
        <MemoryRouter>
          <RequireRole roles={['care_coordinator']}>
            <div>CREATE PATIENT PAGE</div>
          </RequireRole>
        </MemoryRouter>
      );
      expect(screen.queryByText('CREATE PATIENT PAGE')).not.toBeInTheDocument();
      expect(screen.getByText("You don't have access to this page")).toBeInTheDocument();
    }
  );
});
