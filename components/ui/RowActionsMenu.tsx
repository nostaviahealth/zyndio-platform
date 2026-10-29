import React, { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { MoreHorizontal } from 'lucide-react';
import { FOCUS_RING_CLASS, FOCUS_RING_INSET_CLASS } from './focusRing';

export interface RowActionItem {
  label: string;
  onClick: () => void;
  destructive?: boolean;
}

interface RowActionsMenuProps {
  email: string;
  items: RowActionItem[];
}

const GAP_PX = 4;
const VIEWPORT_MARGIN_PX = 8;

interface MenuPosition {
  top?: number;
  bottom?: number;
  right: number;
}

// C-series row "more actions" menu (TC-011 Ava H3): a 44x44 icon-button
// trigger + role="menu" popover, replacing the inline text-link actions
// that used to sit in this cell.
//
// TC-019 fix round (Ava F1): the trigger sits in the pinned (sticky) actions
// column of a table that scrolls inside its card, so a menu rendered in the
// cell was painted over by later rows and clipped by the scroller. The menu
// now renders in a portal on document.body, fixed to the trigger's on-screen
// position, and opens upward when there is no room below. It closes on any
// scroll or resize (rather than drifting away from its row), on Escape, Tab
// or an outside click, and keyboard focus moves into it and back.
const RowActionsMenu: React.FC<RowActionsMenuProps> = ({ email, items }) => {
  const [open, setOpen] = useState(false);
  const [position, setPosition] = useState<MenuPosition | null>(null);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);
  const focusFirstOnOpen = useRef(false);

  const close = useCallback((returnFocus: boolean) => {
    setOpen(false);
    setPosition(null);
    if (returnFocus) triggerRef.current?.focus();
  }, []);

  // Place the menu against the trigger once it has rendered (its height is
  // needed to decide whether it fits below).
  useLayoutEffect(() => {
    if (!open || !triggerRef.current || !menuRef.current) return;
    const t = triggerRef.current.getBoundingClientRect();
    const menuHeight = menuRef.current.getBoundingClientRect().height;
    const right = Math.max(VIEWPORT_MARGIN_PX, window.innerWidth - t.right);
    const roomBelow = window.innerHeight - t.bottom - GAP_PX - VIEWPORT_MARGIN_PX;
    const roomAbove = t.top - GAP_PX - VIEWPORT_MARGIN_PX;
    if (menuHeight > roomBelow && roomAbove > roomBelow) {
      setPosition({ bottom: window.innerHeight - t.top + GAP_PX, right });
    } else {
      setPosition({ top: t.bottom + GAP_PX, right });
    }
  }, [open]);

  useEffect(() => {
    if (!open || !position || !focusFirstOnOpen.current) return;
    focusFirstOnOpen.current = false;
    menuRef.current?.querySelector<HTMLElement>('[role="menuitem"]')?.focus();
  }, [open, position]);

  useEffect(() => {
    if (!open) return;
    const handlePointerDown = (e: MouseEvent) => {
      const target = e.target as Node;
      if (triggerRef.current?.contains(target) || menuRef.current?.contains(target)) return;
      close(false);
    };
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        close(true);
      }
    };
    const handleScrollOrResize = (e: Event) => {
      // Scrolling inside the menu itself (never happens at 3 items) is fine.
      if (e.type === 'scroll' && e.target instanceof Node && menuRef.current?.contains(e.target)) return;
      close(false);
    };
    document.addEventListener('mousedown', handlePointerDown);
    document.addEventListener('keydown', handleKeyDown);
    // Capture: scroll events don't bubble, and the table scrolls in its card.
    window.addEventListener('scroll', handleScrollOrResize, true);
    window.addEventListener('resize', handleScrollOrResize);
    return () => {
      document.removeEventListener('mousedown', handlePointerDown);
      document.removeEventListener('keydown', handleKeyDown);
      window.removeEventListener('scroll', handleScrollOrResize, true);
      window.removeEventListener('resize', handleScrollOrResize);
    };
  }, [open, close]);

  const handleMenuKeyDown = (e: React.KeyboardEvent<HTMLDivElement>) => {
    const menuItems = Array.from(menuRef.current?.querySelectorAll<HTMLElement>('[role="menuitem"]') ?? []);
    if (menuItems.length === 0) return;
    const index = menuItems.indexOf(document.activeElement as HTMLElement);
    let next: number | null = null;
    if (e.key === 'ArrowDown') next = (index + 1) % menuItems.length;
    else if (e.key === 'ArrowUp') next = (index - 1 + menuItems.length) % menuItems.length;
    else if (e.key === 'Home') next = 0;
    else if (e.key === 'End') next = menuItems.length - 1;
    else if (e.key === 'Tab') {
      // The panel lives at the end of <body>; leaving it returns to the row.
      e.preventDefault();
      close(true);
      return;
    }
    if (next !== null) {
      e.preventDefault();
      menuItems[next].focus();
    }
  };

  if (items.length === 0) return null;

  return (
    <div className="relative inline-block text-left">
      <button
        ref={triggerRef}
        type="button"
        aria-label={`More actions for ${email}`}
        aria-haspopup="menu"
        aria-expanded={open}
        onClick={() => {
          if (open) {
            close(false);
          } else {
            // Menu-button pattern: focus moves to the first item on open.
            focusFirstOnOpen.current = true;
            setOpen(true);
          }
        }}
        className={`flex h-11 w-11 items-center justify-center rounded-full text-slate-500 hover:bg-slate-100 dark:text-[#A6B0C3] dark:hover:bg-[#222838] ${FOCUS_RING_CLASS}`}
      >
        <MoreHorizontal className="h-5 w-5" aria-hidden="true" />
      </button>
      {open &&
        createPortal(
          <div
            ref={menuRef}
            role="menu"
            aria-label={`Actions for ${email}`}
            onKeyDown={handleMenuKeyDown}
            style={{
              position: 'fixed',
              top: position?.top !== undefined ? `${position.top}px` : undefined,
              bottom: position?.bottom !== undefined ? `${position.bottom}px` : undefined,
              right: position ? `${position.right}px` : undefined,
              visibility: position ? undefined : 'hidden',
            }}
            className="z-50 w-56 rounded-xl border border-slate-200 bg-white py-1 shadow-lg dark:border-[#222838] dark:bg-[#10141F] dark:shadow-black/40"
          >
            {items.map((item) => (
              <button
                key={item.label}
                type="button"
                role="menuitem"
                onClick={() => {
                  close(true);
                  item.onClick();
                }}
                className={`flex min-h-[44px] w-full items-center px-4 text-left text-sm hover:bg-slate-50 dark:hover:bg-[#222838] ${FOCUS_RING_INSET_CLASS} ${
                  item.destructive ? 'font-semibold text-red-600 dark:text-[#FF8F86]' : 'text-slate-700 dark:text-[#EEF1F8]'
                }`}
              >
                {item.label}
              </button>
            ))}
          </div>,
          document.body
        )}
    </div>
  );
};

export default RowActionsMenu;
