// @vitest-environment jsdom
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { useIdleTimer, IDLE_WARNING_MS, IDLE_EXPIRE_MS } from '../../hooks/useIdleTimer';

describe('useIdleTimer', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('fires onWarning at 13 minutes and onExpire at 15 minutes idle', () => {
    const onWarning = vi.fn();
    const onExpire = vi.fn();
    const { result } = renderHook(() => useIdleTimer({ onWarning, onExpire }));

    expect(result.current.state).toBe('active');

    act(() => {
      vi.advanceTimersByTime(IDLE_WARNING_MS - 1);
    });
    expect(onWarning).not.toHaveBeenCalled();

    act(() => {
      vi.advanceTimersByTime(1);
    });
    expect(onWarning).toHaveBeenCalledTimes(1);
    expect(result.current.state).toBe('warning');
    expect(onExpire).not.toHaveBeenCalled();

    act(() => {
      vi.advanceTimersByTime(IDLE_EXPIRE_MS - IDLE_WARNING_MS);
    });
    expect(onExpire).toHaveBeenCalledTimes(1);
    expect(result.current.state).toBe('expired');
  });

  it('does not reset the idle clock on mousemove', () => {
    const onWarning = vi.fn();
    renderHook(() => useIdleTimer({ onWarning }));

    act(() => {
      vi.advanceTimersByTime(IDLE_WARNING_MS - 1000);
      window.dispatchEvent(new Event('mousemove'));
      vi.advanceTimersByTime(1000);
    });

    expect(onWarning).toHaveBeenCalledTimes(1);
  });

  it('resets the idle clock on keydown', () => {
    const onWarning = vi.fn();
    renderHook(() => useIdleTimer({ onWarning }));

    act(() => {
      vi.advanceTimersByTime(IDLE_WARNING_MS - 1000);
      window.dispatchEvent(new Event('keydown'));
      vi.advanceTimersByTime(1000);
    });

    expect(onWarning).not.toHaveBeenCalled();

    act(() => {
      vi.advanceTimersByTime(IDLE_WARNING_MS - 1000);
    });
    expect(onWarning).toHaveBeenCalledTimes(1);
  });

  it('reset() dismisses the warning and restarts the clock', () => {
    const onWarning = vi.fn();
    const onExpire = vi.fn();
    const { result } = renderHook(() => useIdleTimer({ onWarning, onExpire }));

    act(() => {
      vi.advanceTimersByTime(IDLE_WARNING_MS);
    });
    expect(result.current.state).toBe('warning');

    act(() => {
      result.current.reset();
    });
    expect(result.current.state).toBe('active');

    act(() => {
      vi.advanceTimersByTime(IDLE_EXPIRE_MS - 1);
    });
    expect(onExpire).not.toHaveBeenCalled();
  });
});
