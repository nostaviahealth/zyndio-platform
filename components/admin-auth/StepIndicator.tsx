import React from 'react';

const StepIndicator: React.FC<{ step: number; total: number }> = ({ step, total }) => (
  <p className="mb-2 text-xs font-semibold uppercase tracking-[0.1em] text-slate-500">
    Step {step} of {total}
  </p>
);

export default StepIndicator;
