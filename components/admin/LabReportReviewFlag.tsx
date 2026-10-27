import React, { useState } from 'react';
import { Flag } from 'lucide-react';
import { flagLabReportNeedsReview } from '../../lib/labReportsApi';

interface LabReportReviewFlagProps {
  labReportId: string;
  initialNeedsReview: boolean;
  // care_coordinator and physician may both flag (RPC-enforced server
  // side); any other role gets no affordance at all.
  canFlag: boolean;
}

// TC-011 M2: minimal UI hook for the flag-only review RPC. Deliberately not
// a full lab-review surface - a coordinator can only raise this flag, never
// edit or confirm the report's data (that stays physician-only).
const LabReportReviewFlag: React.FC<LabReportReviewFlagProps> = ({ labReportId, initialNeedsReview, canFlag }) => {
  const [needsReview, setNeedsReview] = useState(initialNeedsReview);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (needsReview) {
    return (
      <span className="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-semibold bg-amber-100 text-amber-700">
        <Flag className="w-3 h-3" /> Needs review
      </span>
    );
  }

  if (!canFlag) return null;

  const onFlag = async () => {
    setSubmitting(true);
    setError(null);
    const result = await flagLabReportNeedsReview(labReportId);
    setSubmitting(false);
    if (result.ok) {
      setNeedsReview(true);
    } else {
      setError('Could not flag this report. Try again.');
    }
  };

  return (
    <div className="inline-flex flex-col items-start gap-1">
      <button
        type="button"
        onClick={onFlag}
        disabled={submitting}
        className="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-semibold bg-slate-100 text-slate-600 hover:bg-amber-100 hover:text-amber-700 transition-colors disabled:opacity-50"
      >
        <Flag className="w-3 h-3" /> {submitting ? 'Flagging…' : 'Flag for review'}
      </button>
      {error && <span className="text-xs text-red-600">{error}</span>}
    </div>
  );
};

export default LabReportReviewFlag;
