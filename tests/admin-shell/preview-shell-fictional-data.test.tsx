// @vitest-environment jsdom
// TC-013 Ava L9: the preview/screenshot harness always shows a
// "FICTIONAL DATA" tag in the top-right corner of the page.
import React from 'react';
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import PreviewShell from '../../pages/preview/PreviewShell';

describe('PreviewShell fictional data tag', () => {
  it('renders a FICTIONAL DATA tag', () => {
    render(
      <PreviewShell mode="light">
        <div>content</div>
      </PreviewShell>
    );
    expect(screen.getByText('Fictional data')).toBeInTheDocument();
  });
});
