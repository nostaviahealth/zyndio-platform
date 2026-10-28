import React, { useId } from 'react';

interface TextFieldProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label: string;
  error?: boolean;
  hint?: string;
}

const TextField = React.forwardRef<HTMLInputElement, TextFieldProps>(
  ({ label, error, hint, id, className = '', ...rest }, ref) => {
    const generatedId = useId();
    const fieldId = id ?? generatedId;
    const hintId = hint ? `${fieldId}-hint` : undefined;

    return (
      <div className="space-y-1.5">
        <label htmlFor={fieldId} className="block text-sm font-semibold text-slate-800">
          {label}
        </label>
        <input
          ref={ref}
          id={fieldId}
          aria-invalid={error || undefined}
          aria-describedby={hintId}
          className={`w-full min-h-[44px] px-4 rounded-xl border bg-white text-slate-900 placeholder-slate-400 focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-1 focus-visible:ring-[#2C5CF2] ${
            error ? 'border-red-500' : 'border-slate-300'
          } ${className}`}
          {...rest}
        />
        {hint && (
          <p id={hintId} className="text-xs text-slate-500">
            {hint}
          </p>
        )}
      </div>
    );
  }
);
TextField.displayName = 'TextField';

export default TextField;
