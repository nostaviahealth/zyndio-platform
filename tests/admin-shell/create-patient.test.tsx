// @vitest-environment jsdom
// TC-018 (Henry add-on, Create Patient): the page used to call
// AdminContext.createPatient(), which inserted into the removed `profiles`
// table - "Failed to create patient" for every allowed role (PR #22 review,
// L2). It must now call the real patients-table-backed API
// (lib/patientsApi.createPatient) with the fields the real table supports
// (display name, email, optional MRN - age/gender/plan/stage/payment have
// no home without a shadow table) and show a visible error on failure
// instead of only logging to console.
//
// CI theme-check item 25 (Clara, PR #23 review): this rewrite also stopped
// raising the shared AdminContext toast on success - the only feedback was a
// full-page "Patient Created Successfully!" card, which nothing elsewhere in
// the admin app (and no toast assertion) can see. Restored below so Create
// Patient matches every other AdminContext mutation (update/delete patient,
// save/delete diet plan), which all raise the same toast.
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';

const createPatient = vi.fn(async () => ({ ok: true, patientId: 'new-patient-1' }));
vi.mock('../../lib/patientsApi', () => ({
  createPatient: (...args: unknown[]) => createPatient(...args),
}));

const navigate = vi.fn();
vi.mock('react-router-dom', async () => {
  const actual = await vi.importActual<typeof import('react-router-dom')>('react-router-dom');
  return { ...actual, useNavigate: () => navigate };
});

// AdminContext.showToast now backs the success/error feedback, so
// CreatePatient needs a real AdminProvider in the tree (Clara, PR #23 review
// finding #8: the previous version of this test rendered CreatePatient with
// no AdminProvider at all, so it could never have exercised useAdmin()).
// AdminProvider itself queries `patients`/`diet_plans` on mount; stub
// lib/supabase the same way tests/admin-shell/admin-context-no-profiles.test.tsx
// does so that mount effect resolves harmlessly.
vi.mock('../../lib/supabase', () => {
  const from = () => {
    const builder: Record<string, unknown> = {};
    for (const m of ['select', 'eq', 'order', 'insert', 'update', 'delete', 'upsert', 'single']) {
      builder[m] = () => builder;
    }
    builder.then = (resolve: (v: unknown) => unknown) => Promise.resolve({ data: [], error: null }).then(resolve);
    return builder;
  };
  return { supabase: { from } };
});

import { AdminProvider } from '../../contexts/AdminContext';
import CreatePatient from '../../pages/admin/CreatePatient';

function renderPage() {
  return render(
    <MemoryRouter>
      <AdminProvider>
        <CreatePatient />
      </AdminProvider>
    </MemoryRouter>
  );
}

describe('CreatePatient page', () => {
  it('submits display name, email and mrn to the real patients API', async () => {
    const user = userEvent.setup();
    renderPage();

    await user.type(screen.getByLabelText(/full name/i), 'Fictional Patient');
    await user.type(screen.getByLabelText(/email/i), 'fictional.patient@example.test');
    await user.type(screen.getByLabelText(/medical record number/i), 'MRN-123');
    await user.click(screen.getByRole('button', { name: /create patient/i }));

    await waitFor(() => expect(createPatient).toHaveBeenCalled());
    expect(createPatient.mock.calls[0]).toEqual(['fictional.patient@example.test', 'Fictional Patient', 'MRN-123']);
    // Both the full-page "Patient Created Successfully!" card and the
    // AdminContext toast are now present - assert each by its own exact
    // text so the toast's existence is checked specifically, not folded
    // into the same case-insensitive match as the card's heading.
    await waitFor(() => expect(screen.getByText('Patient Created Successfully!')).toBeInTheDocument());
    await waitFor(() => expect(screen.getByText('Patient created successfully')).toBeInTheDocument());
  });

  it('shows a visible error banner when the API call fails, not just a console log', async () => {
    createPatient.mockResolvedValueOnce({ ok: false, error: 'not_authorized' });
    const user = userEvent.setup();
    renderPage();

    await user.type(screen.getByLabelText(/full name/i), 'Fictional Patient');
    await user.type(screen.getByLabelText(/email/i), 'fictional.patient2@example.test');
    await user.click(screen.getByRole('button', { name: /create patient/i }));

    await waitFor(() => expect(createPatient).toHaveBeenCalled());
    expect(await screen.findByText(/couldn't create|failed to create/i)).toBeInTheDocument();
    expect(screen.queryByText(/patient created successfully/i)).not.toBeInTheDocument();
  });
});
