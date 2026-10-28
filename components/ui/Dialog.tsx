import React, { useEffect, useRef } from 'react';

interface DialogProps {
  titleId: string;
  descriptionId?: string;
  title: React.ReactNode;
  children?: React.ReactNode;
  onClose: () => void;
  initialFocusSelector?: string;
}

// Generic C-series confirm/form dialog: focus-trapped role=alertdialog,
// Escape closes, matches the pattern already proven in
// components/admin-shell/IdleWarningDialog.tsx (kept separate - that one
// intentionally can't be dismissed by Escape/backdrop).
const Dialog: React.FC<DialogProps> = ({
  titleId,
  descriptionId,
  title,
  children,
  onClose,
  initialFocusSelector = '[data-autofocus]',
}) => {
  const dialogRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const node = dialogRef.current;
    (node?.querySelector<HTMLElement>(initialFocusSelector) ?? node?.querySelector<HTMLElement>('button'))?.focus();
  }, [initialFocusSelector]);

  useEffect(() => {
    const node = dialogRef.current;
    if (!node) return;
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        onClose();
        return;
      }
      if (e.key !== 'Tab') return;
      const focusable = node.querySelectorAll<HTMLElement>(
        'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
      );
      if (focusable.length === 0) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    };
    node.addEventListener('keydown', handleKeyDown);
    return () => node.removeEventListener('keydown', handleKeyDown);
  }, [onClose]);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 px-4">
      <div
        ref={dialogRef}
        role="alertdialog"
        aria-modal="true"
        aria-labelledby={titleId}
        aria-describedby={descriptionId}
        className="w-full max-w-[480px] rounded-2xl bg-white p-6 shadow-xl"
      >
        <h2 id={titleId} className="text-lg font-bold text-[#030616]">
          {title}
        </h2>
        {children}
      </div>
    </div>
  );
};

export default Dialog;
