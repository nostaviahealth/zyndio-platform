import React from 'react';
import { FOCUS_RING_CLASS } from './focusRing';

export const SELECT_FIELD_CLASS =
  `h-11 w-full appearance-none rounded-[10px] border border-[#7A86A0] bg-white pl-4 pr-10 text-sm text-[#030616] dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8] ${FOCUS_RING_CLASS}`;

/** Design `.sel` caret: 18×18 chevron, stroke = text-secondary. */
export const SelectCaret: React.FC = () => (
  <svg
    aria-hidden="true"
    data-testid="select-caret"
    className="pointer-events-none absolute right-3 top-1/2 h-[18px] w-[18px] -translate-y-1/2 text-[#48556A] dark:text-[#A6B0C3]"
    width="18"
    height="18"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="1.8"
    strokeLinecap="round"
    strokeLinejoin="round"
  >
    <path d="M6 9l6 6 6-6" />
  </svg>
);

type SelectFieldProps = React.SelectHTMLAttributes<HTMLSelectElement> & {
  wrapperClassName?: string;
};

// TC-013 Ava H2: role / status selects match design `.sel` (44px, r=10px,
// border-strong) with a token-colored SVG caret after appearance-none.
const SelectField = React.forwardRef<HTMLSelectElement, SelectFieldProps>(
  ({ className = '', wrapperClassName = '', children, ...rest }, ref) => (
    <div className={`relative inline-flex min-w-0 ${wrapperClassName}`}>
      <select ref={ref} className={`${SELECT_FIELD_CLASS} ${className}`.trim()} {...rest}>
        {children}
      </select>
      <SelectCaret />
    </div>
  ),
);
SelectField.displayName = 'SelectField';

export default SelectField;
