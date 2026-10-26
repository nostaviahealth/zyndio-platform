import React, { useRef } from 'react';

interface CodeInputProps {
  length?: number;
  value: string;
  onChange: (value: string) => void;
  onComplete?: (value: string) => void;
  error?: boolean;
  disabled?: boolean;
  label: string;
  autoFocus?: boolean;
}

// Henry's override: one real <input>, autocomplete="one-time-code" - the
// per-cell boxes are purely visual (CSS), not separate inputs, so paste and
// autofill behave like any normal text field.
const CodeInput: React.FC<CodeInputProps> = ({
  length = 6,
  value,
  onChange,
  onComplete,
  error,
  disabled,
  label,
  autoFocus,
}) => {
  const inputRef = useRef<HTMLInputElement>(null);
  const cells = Array.from({ length }, (_, i) => value[i] ?? '');

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const digits = e.target.value.replace(/\D/g, '').slice(0, length);
    onChange(digits);
    if (digits.length === length) onComplete?.(digits);
  };

  return (
    <div className="relative inline-block">
      <label htmlFor="code-input" className="sr-only">
        {label}
      </label>
      <div className="flex gap-2" aria-hidden="true">
        {cells.map((digit, i) => (
          <div
            key={i}
            className={`flex h-14 w-14 items-center justify-center rounded-xl border text-xl font-semibold ${
              error ? 'border-red-500 text-red-600' : 'border-slate-300 text-slate-900'
            }`}
          >
            {digit}
          </div>
        ))}
      </div>
      <input
        ref={inputRef}
        id="code-input"
        type="text"
        inputMode="numeric"
        autoComplete="one-time-code"
        maxLength={length}
        value={value}
        onChange={handleChange}
        disabled={disabled}
        autoFocus={autoFocus}
        aria-invalid={error || undefined}
        className="absolute inset-0 h-full w-full cursor-text opacity-0"
      />
    </div>
  );
};

export default CodeInput;
