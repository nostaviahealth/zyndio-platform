// @vitest-environment jsdom
// components.md C54: Flag badge text is always "nowrap" (the badge itself
// never breaks mid-label); the cell it sits in may still wrap between badges.
import React from 'react';
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';

import FlagBadge from '../../components/clinical/FlagBadge';

describe('FlagBadge', () => {
  it('never wraps its own text', () => {
    render(<FlagBadge flag="question_waiting" />);
    expect(screen.getByText('Question waiting').className).toMatch(/whitespace-nowrap/);
  });
});
