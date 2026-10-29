// @vitest-environment jsdom
// specs.md L8: at the 96 rail the Review queue count badge sits on its icon
// (not stacked below the label as a third flex item), as in Ava's tablet
// render (states/01-patient-list/tablet/*.png).
import React from 'react';
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import PreviewShell from '../../pages/preview/PreviewShell';

describe('PreviewShell rail badge', () => {
  it('positions the Review queue badge over the icon, not below the label', () => {
    render(
      <PreviewShell mode="light" variant="clinical">
        <div>content</div>
      </PreviewShell>
    );
    // Two copies exist (rail vs. ≥1280 desktop row), toggled by a responsive
    // class pair; jsdom doesn't evaluate the media query, so both are in the
    // tree - assert the rail copy specifically: it sits inside the icon's own
    // relative wrapper, absolutely positioned over its corner.
    const badges = screen.getAllByLabelText('7 waiting');
    const railBadge = badges.find((b) => b.className.includes('absolute'));
    expect(railBadge).toBeDefined();
    expect(railBadge?.parentElement?.className).toMatch(/relative/);
  });
});
