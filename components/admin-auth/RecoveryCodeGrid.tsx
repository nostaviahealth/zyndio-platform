import React from 'react';

const RecoveryCodeGrid: React.FC<{ codes: string[] }> = ({ codes }) => (
  <ul aria-label={`${codes.length} recovery codes`} className="grid grid-cols-2 gap-2 rounded-xl bg-slate-50 p-4 font-mono text-sm">
    {codes.map((code) => (
      <li key={code}>{code}</li>
    ))}
  </ul>
);

export default RecoveryCodeGrid;
