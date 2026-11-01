// @vitest-environment jsdom
// TC-018 (Henry add-on, Create Patient): the page used to call
// AdminContext.createPatient(), which inserted into the removed `profiles`
// table - "Failed to create patient" for every allowed role (PR #22 review,
// L2). It must now call the real patients-table-backed API
// (lib/patientsApi.createPatient) with the fields the real table supports
// (display name, email, optional MRN - age/gender/plan/stage/payment have
// no home without a shadow table) and show a visible error on failure
// instead of only logging to console.
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

import CreatePatient from '../../pages/admin/CreatePatient';

function renderPage() {
  return render(
    <MemoryRouter>
      <CreatePatient />
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
    await waitFor(() => expect(screen.getByText(/patient created successfully/i)).toBeInTheDocument());
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
