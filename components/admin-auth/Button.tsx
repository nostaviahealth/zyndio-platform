import React from 'react';

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'outline' | 'destructive';
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
    'inline-flex items-center justify-center gap-2 min-h-[44px] px-6 rounded-full font-semibold text-sm transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-[#2C5CF2] disabled:opacity-60 disabled:cursor-not-allowed';
  const variants: Record<string, string> = {
    primary: 'bg-[#2C5CF2] text-white hover:bg-[#2347c4]',
    outline: 'bg-transparent border border-slate-300 text-slate-900 hover:bg-slate-50',
    destructive: 'bg-red-600 text-white hover:bg-red-700',
  };

  return (
    <button
      className={`${base} ${variants[variant]} ${className}`}
      disabled={disabled || busy}
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
