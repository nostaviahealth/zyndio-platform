import React from 'react';
import { ShieldCheck } from 'lucide-react';

interface TwoFactorStatusProps {
  value: string;
}

// TC-013 Ava M5: "On" gets a check icon in success green; anything else
// (e.g. "Not set up yet") renders as secondary text with no icon, matching
// handoff/admin/states/07-users-roles.
const TwoFactorStatus: React.FC<TwoFactorStatusProps> = ({ value }) => {
  if (value === 'On') {
    return (
      <span className="inline-flex items-center gap-1.5 text-sm font-medium text-emerald-700 dark:text-[#5FD39A]">
        <ShieldCheck className="h-4 w-4" aria-hidden="true" />
        On
      </span>
    );
  }
  return <span className="text-sm text-slate-500 dark:text-[#A6B0C3]">{value}</span>;
};

export default TwoFactorStatus;
