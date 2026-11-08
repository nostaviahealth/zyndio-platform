// @vitest-environment jsdom
// POR-05 Reference ranges page, PP-01 Plan and modules page, and the sidebar
// entries that reach them.
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';

const mockUsePortalAuth = vi.fn();
vi.mock('../../contexts/PortalAuthContext', () => ({
  usePortalAuth: () => mockUsePortalAuth(),
}));

import ReferenceRanges, { validateRangeItem } from '../../pages/admin/clinic/ReferenceRanges';
import PlanModules from '../../pages/admin/PlanModules';
import Sidebar from '../../components/admin-shell/Sidebar';
import { OrgPlan, PlanApi, RangeItem, RangeSet, RangesApi, mapPlan } from '../../lib/clinicConfigApi';

const LIVE: RangeSet = {
  id: 's1', version: 1, status: 'approved', note: null, itemCount: 1, createdByName: 'Dr Fictional Lee',
  createdAt: '2026-10-01T00:00:00Z', approvedByName: 'Dr Fictional Lee', approvedAt: '2026-10-02T00:00:00Z', closedAt: null,
};
const DRAFT: RangeSet = { ...LIVE, id: 's2', version: 2, status: 'draft', approvedByName: null, approvedAt: null };
const ITEM: RangeItem = { id: 'i1', analyteKey: 'hba1c', analyteLabel: 'HbA1c', sex: 'any', low: null, high: 5.7, unit: '%' };

function rangesApi(sets: RangeSet[], over: Partial<RangesApi> = {}): RangesApi {
  return {
    listRangeSets: vi.fn().mockResolvedValue(sets),
    fetchRangeItems: vi.fn().mockResolvedValue([ITEM]),
    createDraft: vi.fn().mockResolvedValue('s2'),
    saveItem: vi.fn().mockResolvedValue(undefined),
    deleteItem: vi.fn().mockResolvedValue(undefined),
    approve: vi.fn().mockResolvedValue(undefined),
    discard: vi.fn().mockResolvedValue(undefined),
    ...over,
  };
}

describe('POR-05 Reference ranges page', () => {
  it('no approved set: says labs use the default range and caveat; physician can start the first set', async () => {
    const user = userEvent.setup();
    const api = rangesApi([]);
    render(<ReferenceRanges api={api} viewerRole="physician" />);
    expect(await screen.findByText(/No approved range set yet/)).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: /Start the first range set/ }));
    expect(api.createDraft).toHaveBeenCalledWith(null);
  });

  it('live set: shows version, approver and row count; read-only roles get no edit controls', async () => {
    const api = rangesApi([LIVE]);
    render(<ReferenceRanges api={api} viewerRole="read_only" />);
    expect(await screen.findByText('Version 1 is live.')).toBeInTheDocument();
    expect(screen.getByText(/Approved by Dr Fictional Lee on Oct 2, 2026/)).toBeInTheDocument();
    expect(await screen.findByRole('cell', { name: /HbA1c/ })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /Start a new version/ })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /Approve/ })).not.toBeInTheDocument();
    expect(screen.queryByRole('form', { name: 'Add or replace a range' })).not.toBeInTheDocument();
  });

  it('physician edits a draft: validates, saves, deletes, approves after confirming', async () => {
    const user = userEvent.setup();
    const api = rangesApi([DRAFT, LIVE]);
    render(<ReferenceRanges api={api} viewerRole="physician" />);
    const form = await screen.findByRole('form', { name: 'Add or replace a range' });

    // Client-side validation (the server checks the same rules).
    await user.type(within(form).getByLabelText('Marker key'), 'glucose_fasting');
    await user.type(within(form).getByLabelText('Marker name'), 'Glucose, fasting');
    await user.type(within(form).getByLabelText('Low'), '99');
    await user.type(within(form).getByLabelText('High'), '70');
    await user.type(within(form).getByLabelText('Unit'), 'mg/dL');
    await user.click(within(form).getByRole('button', { name: 'Save range' }));
    expect(await within(form).findByRole('alert')).toHaveTextContent('Low must be less than high.');
    expect(api.saveItem).not.toHaveBeenCalled();

    await user.clear(within(form).getByLabelText('Low'));
    await user.clear(within(form).getByLabelText('High'));
    await user.type(within(form).getByLabelText('Low'), '70');
    await user.type(within(form).getByLabelText('High'), '99');
    await user.click(within(form).getByRole('button', { name: 'Save range' }));
    await waitFor(() =>
      expect(api.saveItem).toHaveBeenCalledWith('s2', {
        analyteKey: 'glucose_fasting', analyteLabel: 'Glucose, fasting', sex: 'any', low: 70, high: 99, unit: 'mg/dL',
      })
    );

    await user.click(screen.getByRole('button', { name: 'Delete HbA1c (Any)' }));
    expect(api.deleteItem).toHaveBeenCalledWith('i1');

    await user.click(screen.getByRole('button', { name: 'Approve and make live' }));
    const dialog = screen.getByRole('alertdialog');
    expect(dialog).toHaveTextContent('replacing version 1');
    expect(api.approve).not.toHaveBeenCalled();
    await user.click(within(dialog).getByRole('button', { name: 'Approve and make live' }));
    await waitFor(() => expect(api.approve).toHaveBeenCalledWith('s2'));
  });

  it('care coordinator sees a draft but cannot change it', async () => {
    render(<ReferenceRanges api={rangesApi([DRAFT, LIVE])} viewerRole="care_coordinator" />);
    expect(await screen.findByText('Only a physician can edit or approve a draft.')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Approve and make live' })).not.toBeInTheDocument();
  });

  it('a refused server action shows an error and changes nothing on screen', async () => {
    const user = userEvent.setup();
    const api = rangesApi([DRAFT, LIVE], { approve: vi.fn().mockRejectedValue(new Error('42501')) });
    render(<ReferenceRanges api={api} viewerRole="physician" />);
    await user.click(await screen.findByRole('button', { name: 'Approve and make live' }));
    await user.click(within(screen.getByRole('alertdialog')).getByRole('button', { name: 'Approve and make live' }));
    expect(await screen.findByText(/We couldn't approve this version. Nothing changed./)).toBeInTheDocument();
  });

  it('validateRangeItem mirrors the server rules', () => {
    const ok = { analyteKey: 'hba1c', analyteLabel: 'HbA1c', sex: 'any' as const, low: null, high: 5.7, unit: '%' };
    expect(validateRangeItem(ok)).toBeNull();
    expect(validateRangeItem({ ...ok, analyteKey: 'HbA1c!' })).toMatch(/Marker key/);
    expect(validateRangeItem({ ...ok, high: null })).toMatch(/low, a high, or both/);
    expect(validateRangeItem({ ...ok, unit: ' ' })).toMatch(/unit/);
  });
});

const PLAN: OrgPlan = mapPlan({
  tier: 'core',
  standard_modules: ['wearables'],
  effective_from: '2026-10-01T00:00:00Z',
  max_standard_modules: 2,
  catalog: [
    { module_key: 'patient_app', label: 'Patient app', kind: 'core', is_placeholder: true },
    { module_key: 'labs_biomarkers', label: 'Labs and biomarkers', kind: 'core', is_placeholder: true },
    { module_key: 'physician_portal', label: 'Physician portal', kind: 'core', is_placeholder: true },
    { module_key: 'treatment_context', label: 'Treatment context', kind: 'core', is_placeholder: true },
    { module_key: 'notifications', label: 'Notifications', kind: 'core', is_placeholder: true },
    { module_key: 'wearables', label: 'Wearables', kind: 'standard', is_placeholder: true },
    { module_key: 'ai_companion', label: 'AI companion', kind: 'standard', is_placeholder: true },
    { module_key: 're_test_recall', label: 'Re-Test Recall', kind: 'standard', is_placeholder: false },
  ],
});

function planApi(over: Partial<PlanApi> = {}): PlanApi {
  return {
    fetchPlan: vi.fn().mockResolvedValue(PLAN),
    fetchHistory: vi.fn().mockResolvedValue([
      { id: '2', tier: 'core', standardModules: ['wearables'], effectiveFrom: '2026-10-01T00:00:00Z', effectiveTo: null, changedByName: 'Fictional Admin', reason: 'Signed order form' },
      { id: '1', tier: 'core', standardModules: [], effectiveFrom: '2026-09-01T00:00:00Z', effectiveTo: '2026-10-01T00:00:00Z', changedByName: null, reason: null },
    ]),
    setPlan: vi.fn().mockResolvedValue(undefined),
    ...over,
  };
}

describe('PP-01 Plan and modules page', () => {
  it('shows Core with five core modules, the placeholder notice, and the billing history', async () => {
    render(<PlanModules api={planApi()} />);
    expect(await screen.findByRole('heading', { name: 'Core tier' })).toBeInTheDocument();
    const core = screen.getByRole('region', { name: 'Core tier' });
    expect(within(core).getAllByRole('listitem')).toHaveLength(5);
    expect(screen.getByText(/not contractual/)).toBeInTheDocument();
    const history = screen.getByRole('region', { name: 'Billing history' });
    expect(within(history).getAllByRole('row')).toHaveLength(3);
    expect(history).toHaveTextContent('Current');
    expect(history).toHaveTextContent('Signed order form');
  });

  it('Re-Test Recall (named in the PRD) is not marked placeholder; the others are', async () => {
    render(<PlanModules api={planApi()} />);
    const recall = (await screen.findByLabelText(/Re-Test Recall/)).closest('label')!;
    expect(within(recall).queryByText('Placeholder')).not.toBeInTheDocument();
    const wearables = screen.getByLabelText(/Wearables/).closest('label')!;
    expect(within(wearables).getByText('Placeholder')).toBeInTheDocument();
  });

  it('caps the choice at two standard modules and saves the sorted list with a reason', async () => {
    const user = userEvent.setup();
    const api = planApi();
    render(<PlanModules api={api} />);
    const save = await screen.findByRole('button', { name: 'Save plan' });
    expect(save).toBeDisabled();

    await user.click(screen.getByLabelText(/Re-Test Recall/));
    expect(screen.getByText(/2 of 2 chosen/)).toBeInTheDocument();
    expect(screen.getByLabelText(/AI companion/)).toBeDisabled();

    await user.type(screen.getByLabelText(/Reason for the change/), 'Added recall module');
    await user.click(save);
    await waitFor(() => expect(api.setPlan).toHaveBeenCalledWith('core', ['re_test_recall', 'wearables'], 'Added recall module'));
    expect(await screen.findByText('Plan saved. A new billing period started now.')).toBeInTheDocument();
  });

  it('a failed save says nothing changed', async () => {
    const user = userEvent.setup();
    render(<PlanModules api={planApi({ setPlan: vi.fn().mockRejectedValue(new Error('42501')) })} />);
    await user.click(await screen.findByLabelText(/AI companion/));
    await user.click(screen.getByRole('button', { name: 'Save plan' }));
    expect(await screen.findByText("We couldn't save the plan. Nothing changed. Try again.")).toBeInTheDocument();
  });

  it('mapPlan treats a missing placeholder flag as placeholder (never silently contractual)', () => {
    expect(mapPlan({ catalog: [{ module_key: 'x', label: 'X', kind: 'standard' }] }).catalog[0].isPlaceholder).toBe(true);
  });
});

describe('Sidebar entries for the new pages', () => {
  const renderAs = (role: string) => {
    mockUsePortalAuth.mockReturnValue({ role, email: 'casey.morgan@example.test', signOut: vi.fn() });
    render(
      <MemoryRouter initialEntries={['/admin']}>
        <Sidebar />
      </MemoryRouter>
    );
  };

  it.each(['physician', 'care_coordinator', 'read_only'])('%s sees Patients and Reference ranges, not admin pages', (role) => {
    renderAs(role);
    expect(screen.getByRole('link', { name: 'Patients' })).toHaveAttribute('href', '/admin/patients');
    expect(screen.getByRole('link', { name: 'Reference ranges' })).toHaveAttribute('href', '/admin/ranges');
    expect(screen.queryByRole('link', { name: 'Plan and modules' })).not.toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Users and roles' })).not.toBeInTheDocument();
  });

  it('org_admin sees Users and roles and Plan and modules, no clinical pages', () => {
    renderAs('org_admin');
    expect(screen.getByRole('link', { name: 'Plan and modules' })).toHaveAttribute('href', '/admin/plan');
    expect(screen.getByRole('link', { name: 'Users and roles' })).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Patients' })).not.toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Reference ranges' })).not.toBeInTheDocument();
  });
});
