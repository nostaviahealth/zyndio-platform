// @vitest-environment jsdom
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

const flagLabReportNeedsReview = vi.fn(async () => ({ ok: true }));

vi.mock('../../lib/labReportsApi', () => ({
  flagLabReportNeedsReview: (...args: unknown[]) => flagLabReportNeedsReview(...args),
}));

import LabReportReviewFlag from '../../components/admin/LabReportReviewFlag';

describe('LabReportReviewFlag', () => {
  beforeEach(() => vi.clearAllMocks());

  it('shows no affordance for a role that cannot flag (e.g. org_admin, read_only)', () => {
    const { container } = render(
      <LabReportReviewFlag labReportId="lab-1" initialNeedsReview={false} canFlag={false} />
    );
    expect(container).toBeEmptyDOMElement();
  });

  it('shows a Flag for review button for care_coordinator/physician and calls the RPC on click', async () => {
    const user = userEvent.setup();
    render(<LabReportReviewFlag labReportId="lab-1" initialNeedsReview={false} canFlag={true} />);
    const button = screen.getByRole('button', { name: /flag for review/i });
    await user.click(button);
    expect(flagLabReportNeedsReview).toHaveBeenCalledWith('lab-1');
    await waitFor(() => expect(screen.getByText('Needs review')).toBeInTheDocument());
  });

  it('shows the Needs review badge (not a button) when already flagged, regardless of role', () => {
    render(<LabReportReviewFlag labReportId="lab-1" initialNeedsReview={true} canFlag={false} />);
    expect(screen.getByText('Needs review')).toBeInTheDocument();
    expect(screen.queryByRole('button')).not.toBeInTheDocument();
  });

  it('shows an error message and keeps the button if the RPC is refused', async () => {
    flagLabReportNeedsReview.mockResolvedValueOnce({ ok: false, error: 'forbidden' });
    const user = userEvent.setup();
    render(<LabReportReviewFlag labReportId="lab-1" initialNeedsReview={false} canFlag={true} />);
    await user.click(screen.getByRole('button', { name: /flag for review/i }));
    await waitFor(() => expect(screen.getByText(/could not flag/i)).toBeInTheDocument());
    expect(screen.getByRole('button', { name: /flag for review/i })).toBeInTheDocument();
  });
});
