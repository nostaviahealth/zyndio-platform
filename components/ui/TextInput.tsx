import React from 'react';
import { FOCUS_RING_CLASS } from './focusRing';

export const TEXT_INPUT_BASE_CLASS =
  'min-h-[44px] w-full rounded-md bg-white px-3 text-sm text-[#030616] disabled:opacity-60 dark:bg-[#10141F] dark:text-[#EEF1F8]';

export const TEXT_INPUT_BORDER_OK = 'border border-slate-300 dark:border-[#6C7690]';
export const TEXT_INPUT_BORDER_ERROR = 'border-2 border-[#B42318] dark:border-[#FF8F86]';

type TextInputProps = React.InputHTMLAttributes<HTMLInputElement> & {
  error?: boolean;
};

/** Shared text input — server/admin forms. Focus ring from focus.ring token. */
const TextInput = React.forwardRef<HTMLInputElement, TextInputProps>(
  ({ className = '', error = false, ...rest }, ref) => (
    <input
      ref={ref}
      className={`${TEXT_INPUT_BASE_CLASS} ${error ? TEXT_INPUT_BORDER_ERROR : TEXT_INPUT_BORDER_OK} ${FOCUS_RING_CLASS} ${className}`.trim()}
      {...rest}
    />
  ),
);
TextInput.displayName = 'TextInput';

export default TextInput;
