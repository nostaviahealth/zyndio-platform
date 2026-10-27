// Ava TC-013: dark-mode ··· row-menu icon must clear WCAG 1.4.11 (≥3:1)
// against the table row surface (bg.surface #10141F). Measured pre-fix
// slate-500 (#64748B) at ~3.87:1 (passes); still switched to text.secondary
// (#A6B0C3) to match the design token for secondary icons.
const SURFACE_DARK = '#10141F';
const ICON_DARK = '#A6B0C3'; // text.secondary
const ICON_PRE_FIX = '#64748B'; // slate-500 (previous)

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

describe('RowActionsMenu dark ··· icon contrast (Ava TC-013)', () => {
  it('documents pre-fix slate-500 on bg.surface was ≥3:1', () => {
    const ratio = contrastRatio(ICON_PRE_FIX, SURFACE_DARK);
    expect(ratio).toBeGreaterThanOrEqual(3);
  });

  it('text.secondary icon on bg.surface clears 3:1', () => {
    const ratio = contrastRatio(ICON_DARK, SURFACE_DARK);
    expect(ratio).toBeGreaterThanOrEqual(3);
    // Keep a readable record for the report.
    expect(ratio).toBeGreaterThan(8);
  });
});
