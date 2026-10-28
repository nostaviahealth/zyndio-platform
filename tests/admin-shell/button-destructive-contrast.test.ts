// Ava TC-014: destructive label must clear WCAG AA (≥4.5:1) in both themes.
// Light: status-critical #B42318 on status-onCritical #FFFFFF
// Dark:  status-critical #FF8F86 on status-onCritical #030616
const LIGHT_BG = '#B42318';
const LIGHT_FG = '#FFFFFF';
const DARK_BG = '#FF8F86';
const DARK_FG = '#030616';
// Pre-fix pale wash that failed review (≈#F9D9D9 with white text).
const PALE_PINK = '#F9D9D9';

function channelLinear(v: number): number {
  const c = v / 255;
  return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
}

function relativeLuminance(hex: string): number {
  const h = hex.replace('#', '');
  const r = parseInt(h.slice(0, 2), 16);
  const g = parseInt(h.slice(2, 4), 16);
  const b = parseInt(h.slice(4, 6), 16);
  return 0.2126 * channelLinear(r) + 0.7152 * channelLinear(g) + 0.0722 * channelLinear(b);
}

function contrastRatio(a: string, b: string): number {
  const la = relativeLuminance(a);
  const lb = relativeLuminance(b);
  const lighter = Math.max(la, lb);
  const darker = Math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

describe('Button destructive label contrast (Ava TC-014)', () => {
  it('light status-critical on white clears 4.5:1', () => {
    const ratio = contrastRatio(LIGHT_FG, LIGHT_BG);
    expect(ratio).toBeGreaterThanOrEqual(4.5);
  });

  it('dark status-critical on #030616 clears 4.5:1', () => {
    const ratio = contrastRatio(DARK_FG, DARK_BG);
    expect(ratio).toBeGreaterThanOrEqual(4.5);
  });

  it('documents the pale-pink wash with white text fails 4.5:1', () => {
    const ratio = contrastRatio(LIGHT_FG, PALE_PINK);
    expect(ratio).toBeLessThan(4.5);
  });
});
