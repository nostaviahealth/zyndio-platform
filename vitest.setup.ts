import '@testing-library/jest-dom/vitest';

// recharts' ResponsiveContainer uses ResizeObserver, which jsdom doesn't
// provide. A no-op shim keeps the clinical trend chart (C59) mountable under
// vitest; the chart's accessible label + table fallback live on the wrapper,
// so tests assert on those rather than the SVG geometry.
if (typeof globalThis.ResizeObserver === 'undefined') {
  class ResizeObserverStub {
    observe(): void {}
    unobserve(): void {}
    disconnect(): void {}
  }
  (globalThis as unknown as { ResizeObserver: typeof ResizeObserverStub }).ResizeObserver = ResizeObserverStub;
}
