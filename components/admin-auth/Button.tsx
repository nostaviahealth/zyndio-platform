import React from 'react';
import { FOCUS_RING_CLASS } from '../ui/focusRing';

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'outline' | 'destructive';
  busy?: boolean;
  busyLabel?: string;
}

// C05/C52 folded into one Button with a destructive variant (plan C).
const Button: React.FC<ButtonProps> = ({
  variant = 'primary',
  busy = false,
  busyLabel,
  className = '',
  children,
  disabled,
  ...rest
}) => {
  const base =
    `inline-flex items-center justify-center gap-2 min-h-[44px] px-6 rounded-full font-semibold text-sm transition-colors disabled:cursor-not-allowed ${FOCUS_RING_CLASS}`;
  // Ava `.btn.o` / `.btn.d` / `.btn.p`: light destructive = status-critical
  // (#B42318) on status-onCritical (#FFF); dark = #FF8F86 on #030616.
  // Outline uses bg-surface (white / #10141F), not transparent — transparent
  // read as dark-filled against some dialog stacks.
  const variants: Record<string, string> = {
    primary: 'bg-[#2C5CF2] text-white hover:bg-[#2347c4] dark:bg-[#7C9CFF] dark:text-[#030616] dark:hover:bg-[#AFC3FF]',
    // Ava `.btn.s` — transparent, brand-primary label (README "secondary").
    secondary:
      'bg-transparent text-[#2C5CF2] hover:bg-[#E8EDFD] dark:text-[#7C9CFF] dark:hover:bg-[#18224A]',
    outline:
      'bg-white border border-slate-300 text-[#030616] hover:bg-slate-50 dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8] dark:hover:bg-[#222838]',
    destructive:
      'bg-[#B42318] text-white hover:bg-[#912018] dark:bg-[#FF8F86] dark:text-[#030616] dark:hover:bg-[#FFB1AA]',
  };

  // Ava sending state: primary stays solid (no opacity wash) while busy;
  // only a true disabled (e.g. Cancel during send) gets the 60% wash.
  const isDisabled = Boolean(disabled || busy);
  const wash = busy ? 'opacity-100' : disabled ? 'opacity-60' : '';

  return (
    <button
      className={`${base} ${variants[variant]} ${wash} ${className}`}
      disabled={isDisabled}
      aria-busy={busy || undefined}
      {...rest}
    >
      {busy && (
        <span
          className="h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent"
          aria-hidden="true"
        />
      )}
      {busy && busyLabel ? busyLabel : children}
    </button>
  );
};

export default Button;
