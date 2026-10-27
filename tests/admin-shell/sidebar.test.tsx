// @vitest-environment jsdom
// TC-011 Ava H1: the live Sidebar (C41/C39) must carry the PLACEHOLDER badge
// and CARE PORTAL tagline next to the ZYNDIO wordmark, matching the design
// handoff's app-shell chrome.
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

const mockUsePortalAuth = vi.fn();
vi.mock('../../contexts/PortalAuthContext', () => ({
  usePortalAuth: () => mockUsePortalAuth(),
}));

import Sidebar from '../../components/admin-shell/Sidebar';

describe('Sidebar wordmark', () => {
  it('shows the ZYNDIO wordmark with the PLACEHOLDER badge and CARE PORTAL tagline', () => {
    mockUsePortalAuth.mockReturnValue({ role: 'org_admin', email: 'taylor.brooks@example.test', signOut: vi.fn() });
    render(
      <MemoryRouter>
        <Sidebar />
      </MemoryRouter>
    );
    expect(screen.getByText('ZYNDIO')).toBeInTheDocument();
    expect(screen.getByText('Placeholder')).toBeInTheDocument();
    expect(screen.getByText('Care Portal')).toBeInTheDocument();
  });
});
