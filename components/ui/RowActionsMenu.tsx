import React, { useEffect, useRef, useState } from 'react';
import { MoreHorizontal } from 'lucide-react';
import { FOCUS_RING_CLASS } from './focusRing';

export interface RowActionItem {
  label: string;
  onClick: () => void;
  destructive?: boolean;
}

interface RowActionsMenuProps {
  email: string;
  items: RowActionItem[];
}

// C-series row "more actions" menu (TC-011 Ava H3): a 44x44 icon-button
// trigger + role="menu" popover, replacing the inline text-link actions
// that used to sit in this cell.
const RowActionsMenu: React.FC<RowActionsMenuProps> = ({ email, items }) => {
  const [open, setOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const handlePointerDown = (e: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) setOpen(false);
    };
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false);
    };
    document.addEventListener('mousedown', handlePointerDown);
    document.addEventListener('keydown', handleKeyDown);
    return () => {
      document.removeEventListener('mousedown', handlePointerDown);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [open]);

  if (items.length === 0) return null;

  return (
    <div className="relative inline-block text-left" ref={containerRef}>
      <button
        type="button"
        aria-label={`More actions for ${email}`}
        aria-haspopup="menu"
        aria-expanded={open}
        onClick={() => setOpen((o) => !o)}
        className={`flex h-11 w-11 items-center justify-center rounded-full text-slate-500 hover:bg-slate-100 dark:text-[#A6B0C3] dark:hover:bg-[#222838] ${FOCUS_RING_CLASS}`}
      >
        <MoreHorizontal className="h-5 w-5" aria-hidden="true" />
      </button>
      {open && (
        <div
          role="menu"
          aria-label={`Actions for ${email}`}
          className="absolute right-0 z-10 mt-1 w-56 rounded-xl border border-slate-200 bg-white py-1 shadow-lg"
        >
          {items.map((item) => (
            <button
              key={item.label}
              type="button"
              role="menuitem"
              onClick={() => {
                setOpen(false);
                item.onClick();
              }}
              className={`flex min-h-[44px] w-full items-center px-4 text-left text-sm hover:bg-slate-50 ${
                item.destructive ? 'font-semibold text-red-600' : 'text-slate-700'
              }`}
            >
              {item.label}
            </button>
          ))}
        </div>
      )}
    </div>
  );
};

export default RowActionsMenu;
