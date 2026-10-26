import React, { useEffect, useRef, useState } from 'react';
import Button from '../admin-auth/Button';

interface IdleWarningDialogProps {
  secondsRemaining: number;
  onStaySignedIn: () => void;
  onSignOut: () => void;
}

const formatCountdown = (totalSeconds: number) => {
  const safe = Math.max(0, totalSeconds);
  const m = Math.floor(safe / 60);
  const s = safe % 60;
  return `${m}:${s.toString().padStart(2, '0')}`;
};

// 05-session/warning: focus-trapped role=alertdialog, visual countdown is
// role=timer aria-live=off, a separate polite region announces only at the
// 60s/30s thresholds (a11y.md "Session timeout").
const IdleWarningDialog: React.FC<IdleWarningDialogProps> = ({
  secondsRemaining,
  onStaySignedIn,
  onSignOut,
}) => {
  const dialogRef = useRef<HTMLDivElement>(null);
  const [announcement, setAnnouncement] = useState('');
  const announcedRef = useRef<Set<number>>(new Set());

  useEffect(() => {
    dialogRef.current?.querySelector<HTMLElement>('[data-autofocus]')?.focus();
  }, []);

  useEffect(() => {
    if ((secondsRemaining === 60 || secondsRemaining === 30) && !announcedRef.current.has(secondsRemaining)) {
      announcedRef.current.add(secondsRemaining);
      setAnnouncement(`Signing out in ${secondsRemaining} seconds`);
    }
  }, [secondsRemaining]);

  useEffect(() => {
    const node = dialogRef.current;
    if (!node) return;
    const handleKeyDown = (e: KeyboardEvent) => {
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
  }, []);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 px-4">
      <div
        ref={dialogRef}
        role="alertdialog"
        aria-modal="true"
        aria-labelledby="idle-warning-title"
        aria-describedby="idle-warning-body"
        className="w-full max-w-[420px] rounded-2xl bg-white p-6 shadow-xl"
      >
        <h2 id="idle-warning-title" className="text-lg font-bold text-[#030616]">
          Are you still there?
        </h2>
        <p id="idle-warning-body" className="mt-2 text-sm text-slate-600">
          For patient privacy, we sign you out after 15 minutes without activity.
        </p>
        <p className="mt-4 text-2xl font-semibold text-[#030616]">
          Signing out in <span role="timer" aria-live="off">{formatCountdown(secondsRemaining)}</span>
        </p>
        <span className="sr-only" role="status" aria-live="polite">
          {announcement}
        </span>
        <div className="mt-6 flex justify-end gap-3">
          <Button type="button" variant="outline" onClick={onSignOut}>
            Sign out
          </Button>
          <Button type="button" variant="primary" data-autofocus="true" onClick={onStaySignedIn}>
            Stay signed in
          </Button>
        </div>
      </div>
    </div>
  );
};

export default IdleWarningDialog;
