// @vitest-environment jsdom
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

import TreatmentContextPanel from '../../components/clinical/TreatmentContextPanel';
import {
  TreatmentApi,
  PatientTreatmentContext,
  mapTreatmentCourse,
  mapTreatmentEvent,
} from '../../lib/treatmentApi';
import AuditLog from '../../pages/admin/AuditLog';
import {
  AuditLogApi,
  AuditLogEntry,
  mapAuditLogRow,
} from '../../lib/auditLogApi';

const SAMPLE_CONTEXT: PatientTreatmentContext = {
  patientId: 'p-1',
  course: {
    id: 'course-1',
    orgId: 'org-1',
    patientId: 'p-1',
    medication: 'Semaglutide',
    formulation: 'Subcutaneous injection',
    currentDoseValue: 0.5,
    currentDoseUnit: 'mg weekly',
    startDate: '2026-09-01',
    status: 'active',
    updatedAt: '2026-10-15T10:00:00Z',
  },
  courses: [],
  events: [
    {
      id: 'ev-2',
      courseId: 'course-1',
      patientId: 'p-1',
      eventType: 'dose_change',
      doseValue: 0.5,
      doseUnit: 'mg weekly',
      statusValue: 'active',
      note: 'Escalated after 4 weeks; mild nausea resolved.',
      effectiveAt: '2026-10-01T09:00:00Z',
      enteredBy: 'doc-1',
      source: 'portal',
      idempotencyKey: null,
      createdAt: '2026-10-01T09:00:00Z',
    },
    {
      id: 'ev-1',
      courseId: 'course-1',
      patientId: 'p-1',
      eventType: 'medication_start',
      doseValue: 0.25,
      doseUnit: 'mg weekly',
      statusValue: 'active',
      note: 'Baseline initiation.',
      effectiveAt: '2026-09-01T09:00:00Z',
      enteredBy: 'doc-1',
      source: 'portal',
      idempotencyKey: null,
      createdAt: '2026-09-01T09:00:00Z',
    },
  ],
};

const SAMPLE_AUDIT_ROWS: AuditLogEntry[] = [
  {
    id: 101,
    action: 'treatment_event_recorded',
    actorId: '11111111-2222-3333-4444-555555555555',
    targetId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    createdAt: '2026-11-01T14:22:00Z',
    metadata: { event_type: 'dose_change', source: 'portal' },
  },
  {
    id: 100,
    action: 'partner_outcome_consent_granted',
    actorId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    targetId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    createdAt: '2026-11-01T12:00:00Z',
    metadata: { partner_code: 'DEXASCAN', consent_version: 'v1.0' },
  },
];

function makeTreatmentApi(overrides: Partial<TreatmentApi> = {}): TreatmentApi {
  return {
    fetchTreatmentContext: vi.fn().mockResolvedValue(SAMPLE_CONTEXT),
    recordTreatmentEvent: vi.fn().mockResolvedValue({
      replayed: false,
      course: SAMPLE_CONTEXT.course!,
      event: SAMPLE_CONTEXT.events[0],
    }),
    ...overrides,
  };
}

function makeAuditApi(overrides: Partial<AuditLogApi> = {}): AuditLogApi {
  return {
    listOrgAuditLog: vi.fn().mockResolvedValue(SAMPLE_AUDIT_ROWS),
    ...overrides,
  };
}

describe('TreatmentContextPanel (POR-07 & Clause 9.1)', () => {
  it('renders the mandatory Clause 9.1 decision-support governance banner and current course', async () => {
    const api = makeTreatmentApi();
    render(<TreatmentContextPanel patientId="p-1" api={api} canEdit={true} />);

    expect(
      await screen.findByText('Recorded treatment context — decision support only'),
    ).toBeInTheDocument();
    expect(
      screen.getByText(/Zyndio never calculates, recommends, or adjusts medication doses/i),
    ).toBeInTheDocument();

    expect(await screen.findByText('Semaglutide')).toBeInTheDocument();
    expect(screen.getByText('Subcutaneous injection')).toBeInTheDocument();
    expect(screen.getByText('0.5 mg weekly')).toBeInTheDocument();
    expect(
      screen.getByText('Escalated after 4 weeks; mild nausea resolved.'),
    ).toBeInTheDocument();
  });

  it('hides the Record treatment event button for read_only staff (canEdit=false)', async () => {
    const api = makeTreatmentApi();
    render(<TreatmentContextPanel patientId="p-1" api={api} canEdit={false} />);

    await screen.findByText('Semaglutide');
    expect(
      screen.queryByRole('button', { name: 'Record treatment event' }),
    ).not.toBeInTheDocument();
  });

  it('validates and submits a new treatment event when physician/care_coordinator records an update', async () => {
    const user = userEvent.setup();
    const api = makeTreatmentApi();
    render(<TreatmentContextPanel patientId="p-1" api={api} canEdit={true} />);

    await screen.findByText('Semaglutide');
    await user.click(screen.getByRole('button', { name: 'Record treatment event' }));

    const doseInput = screen.getByLabelText('Recorded dose value');
    await user.clear(doseInput);
    await user.type(doseInput, '1.0');

    const noteInput = screen.getByLabelText(
      'Tolerability / clinical context note (optional, max 500 chars)',
    );
    await user.type(noteInput, 'Tolerating well at week 8.');

    await user.click(screen.getByRole('button', { name: 'Save event' }));

    await waitFor(() => {
      expect(api.recordTreatmentEvent).toHaveBeenCalledWith(
        expect.objectContaining({
          patientId: 'p-1',
          eventType: 'dose_change',
          doseValue: 1,
          doseUnit: 'mg weekly',
          note: 'Tolerating well at week 8.',
        }),
      );
    });
  });

  it('maps RPC payloads via mapTreatmentCourse and mapTreatmentEvent', () => {
    const course = mapTreatmentCourse({
      id: 'c-10',
      org_id: 'org-1',
      patient_id: 'p-10',
      medication: 'Tirzepatide',
      formulation: 'Auto-injector',
      current_dose_value: 2.5,
      current_dose_unit: 'mg weekly',
      start_date: '2026-10-01',
      status: 'active',
      updated_at: '2026-10-01T00:00:00Z',
    });
    expect(course?.medication).toBe('Tirzepatide');
    expect(course?.currentDoseValue).toBe(2.5);

    const ev = mapTreatmentEvent({
      id: 'e-10',
      course_id: 'c-10',
      patient_id: 'p-10',
      event_type: 'medication_start',
      dose_value: 2.5,
      dose_unit: 'mg weekly',
      status_value: 'active',
      note: 'Started course',
      effective_at: '2026-10-01T00:00:00Z',
      source: 'api',
      created_at: '2026-10-01T00:00:00Z',
    });
    expect(ev.courseId).toBe('c-10');
    expect(ev.source).toBe('api');
  });
});

describe('AuditLog page (POR-08)', () => {
  it('renders organization audit log entries and filters by action', async () => {
    const user = userEvent.setup();
    const api = makeAuditApi();
    render(<AuditLog api={api} />);

    expect(
      await screen.findByRole('heading', { name: 'Audit log' }),
    ).toBeInTheDocument();
    expect(await screen.findByText('treatment_event_recorded')).toBeInTheDocument();
    expect(screen.getByText('partner_outcome_consent_granted')).toBeInTheDocument();

    const filterSelect = screen.getByLabelText('Filter by action');
    await user.selectOptions(filterSelect, 'partner_outcome_consent_granted');

    await waitFor(() => {
      expect(api.listOrgAuditLog).toHaveBeenCalledWith({
        limit: 100,
        actionFilter: 'partner_outcome_consent_granted',
      });
    });
  });

  it('maps RPC rows via mapAuditLogRow', () => {
    const entry = mapAuditLogRow({
      id: 42,
      action: 'patient_detail_opened',
      actor_id: 'u-1',
      target_id: 'p-1',
      created_at: '2026-11-01T00:00:00Z',
      metadata: { role: 'physician' },
    });
    expect(entry.action).toBe('patient_detail_opened');
    expect(entry.actorId).toBe('u-1');
    expect(entry.metadata).toEqual({ role: 'physician' });
  });
});
