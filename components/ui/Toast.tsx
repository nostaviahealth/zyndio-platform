import React, { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';

interface ToastOptions {
  message: string;
  actionLabel?: string;
  onAction?: () => void;
}

interface ToastContextType {
  showToast: (options: ToastOptions) => void;
}

const ToastContext = createContext<ToastContextType | undefined>(undefined);

const DEFAULT_DURATION_MS = 4000;
const WITH_ACTION_DURATION_MS = 8000;

// C-series toast (components.md): role=status so it's announced politely,
// auto-dismisses after 4s (8s when it carries an Undo action), and the
// dismiss timer pauses while hovered or focused so a slow mouse doesn't
// race the Undo click.
export const ToastProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [toast, setToast] = useState<ToastOptions | null>(null);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const remainingRef = useRef(DEFAULT_DURATION_MS);
  const startedAtRef = useRef(0);

  const clearTimer = () => {
    if (timerRef.current) {
      clearTimeout(timerRef.current);
      timerRef.current = null;
    }
  };

  const dismiss = useCallback(() => {
    clearTimer();
    setToast(null);
  }, []);

  const arm = useCallback(
    (ms: number) => {
      clearTimer();
      startedAtRef.current = Date.now();
      remainingRef.current = ms;
      timerRef.current = setTimeout(dismiss, ms);
    },
    [dismiss]
  );

  const showToast = useCallback(
    (options: ToastOptions) => {
      setToast(options);
      arm(options.actionLabel ? WITH_ACTION_DURATION_MS : DEFAULT_DURATION_MS);
    },
    [arm]
  );

  const pause = () => {
    if (!timerRef.current) return;
    clearTimer();
    remainingRef.current -= Date.now() - startedAtRef.current;
  };

  const resume = () => {
    if (!toast || timerRef.current) return;
    arm(Math.max(remainingRef.current, 300));
  };

  useEffect(() => clearTimer, []);

  return (
    <ToastContext.Provider value={{ showToast }}>
      {children}
      {toast && (
        <div
          role="status"
          aria-live="polite"
          onMouseEnter={pause}
          onMouseLeave={resume}
          onFocus={pause}
          onBlur={resume}
          className="fixed bottom-6 left-1/2 z-50 flex -translate-x-1/2 items-center gap-4 rounded-full bg-[#030616] px-5 py-3 text-sm text-white shadow-lg"
        >
          <span>{toast.message}</span>
          {toast.actionLabel && (
            <button
              type="button"
              className="font-semibold text-[#8FB0FF] underline-offset-2 hover:underline focus:outline-none focus-visible:ring-2 focus-visible:ring-white"
              onClick={() => {
                toast.onAction?.();
                dismiss();
              }}
            >
              {toast.actionLabel}
            </button>
          )}
        </div>
      )}
    </ToastContext.Provider>
  );
};

export function useToast(): ToastContextType {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error('useToast must be used within a ToastProvider');
  return ctx;
}
