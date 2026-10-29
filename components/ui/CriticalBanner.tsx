import React from 'react';
import { AlertTriangle } from 'lucide-react';

// C35 banner, err variant: status.critical / criticalSubtle, 20px icon,
// role="alert" (an error following an action, per components.md). Shared by
// the roster and patient-detail error states - same copy pattern, same
// token pair, so one place carries the colours.
const CriticalBanner: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <div role="alert" className="flex items-start gap-3 rounded-2xl bg-[#FCE8E6] px-4 py-3 dark:bg-[#3A1614]">
    <AlertTriangle className="mt-0.5 h-5 w-5 shrink-0 text-[#B42318] dark:text-[#FF8F86]" aria-hidden="true" />
    <p className="text-sm text-[#B42318] dark:text-[#FF8F86]">{children}</p>
  </div>
);

export default CriticalBanner;
