import React from 'react';

// TC-013 Ava L9: a "FICTIONAL DATA" tag in the top-right corner of demo/
// preview builds and the /__preview screenshot harness, so a screenshot can
// never be mistaken for real patient/user data (matches
// handoff/admin/states/07-users-roles).
const FictionalDataTag: React.FC = () => (
  <span className="absolute right-0 top-0 rounded border border-amber-300 bg-amber-50 px-2 py-1 text-[11px] font-bold uppercase tracking-wide text-amber-800">
    Fictional data
  </span>
);

export default FictionalDataTag;
