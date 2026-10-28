import React from 'react';

interface NameCellProps {
  name: string;
  email: string;
}

// Initials from a display name, skipping title fragments like "Dr." (words
// ending in a period) - e.g. "Dr. Morgan Ellis" -> "ME", "Riley Chen" -> "RC".
export function initialsFromName(name: string): string {
  const words = name.split(/\s+/).filter((w) => w.length > 0 && !w.endsWith('.'));
  return words
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase() ?? '')
    .join('');
}

// TC-013 Ava M6: avatar initials + name + email stacked in one cell,
// replacing the separate Email column.
const NameCell: React.FC<NameCellProps> = ({ name, email }) => (
  <div className="flex items-center gap-3">
    <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-[#E8EDFD] text-sm font-semibold text-[#2C5CF2] dark:bg-[#18224A] dark:text-[#AFC3FF]">
      {initialsFromName(name)}
    </div>
    <div className="min-w-0">
      <p className="truncate font-semibold text-[#030616] dark:text-[#EEF1F8]">{name}</p>
      <p className="truncate text-sm text-slate-500 dark:text-[#A6B0C3]">{email}</p>
    </div>
  </div>
);

export default NameCell;
