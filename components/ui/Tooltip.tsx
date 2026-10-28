import React, { useId, useState } from 'react';

// Minimal accessible tooltip: shown on hover AND keyboard focus (title alone
// doesn't fire on focus reliably). Clones the single child to attach
// aria-describedby + the show/hide handlers; Esc dismisses.
interface TooltipChildProps {
  onMouseEnter?: (e: React.MouseEvent) => void;
  onMouseLeave?: (e: React.MouseEvent) => void;
  onFocus?: (e: React.FocusEvent) => void;
  onBlur?: (e: React.FocusEvent) => void;
  onKeyDown?: (e: React.KeyboardEvent) => void;
}

const Tooltip: React.FC<{ label: string; children: React.ReactElement<TooltipChildProps> }> = ({
  label,
  children,
}) => {
  const [open, setOpen] = useState(false);
  const id = useId();

  const child = React.cloneElement(children, {
    'aria-describedby': id,
    onMouseEnter: (e: React.MouseEvent) => {
      children.props.onMouseEnter?.(e);
      setOpen(true);
    },
    onMouseLeave: (e: React.MouseEvent) => {
      children.props.onMouseLeave?.(e);
      setOpen(false);
    },
    onFocus: (e: React.FocusEvent) => {
      children.props.onFocus?.(e);
      setOpen(true);
    },
    onBlur: (e: React.FocusEvent) => {
      children.props.onBlur?.(e);
      setOpen(false);
    },
    onKeyDown: (e: React.KeyboardEvent) => {
      children.props.onKeyDown?.(e);
      if (e.key === 'Escape') setOpen(false);
    },
  } as Partial<TooltipChildProps> & { 'aria-describedby': string });

  return (
    <span className="relative inline-flex">
      {child}
      {open && (
        <span
          role="tooltip"
          id={id}
          className="pointer-events-none absolute left-1/2 top-full z-10 mt-1.5 -translate-x-1/2 whitespace-nowrap rounded-md bg-[#030616] px-2 py-1 text-xs font-medium text-white dark:bg-[#EEF1F8] dark:text-[#030616]"
        >
          {label}
        </span>
      )}
    </span>
  );
};

export default Tooltip;
