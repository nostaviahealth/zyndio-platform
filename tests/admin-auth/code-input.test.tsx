// @vitest-environment jsdom
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import CodeInput from '../../components/admin-auth/CodeInput';

function ControlledHarness({ onComplete }: { onComplete?: (value: string) => void }) {
  const [value, setValue] = React.useState('');
  return <CodeInput label="6-digit code" value={value} onChange={setValue} onComplete={onComplete} />;
}

describe('CodeInput', () => {
  it('renders exactly one real input (autocomplete=one-time-code)', () => {
    render(<CodeInput label="6-digit code" value="" onChange={() => {}} />);
    const inputs = screen.getAllByRole('textbox', { hidden: true });
    expect(inputs).toHaveLength(1);
    expect(inputs[0]).toHaveAttribute('autocomplete', 'one-time-code');
    expect(inputs[0]).toHaveAttribute('maxlength', '6');
  });

  it('shows typed digits in the visual cells and strips non-digits as the user types', async () => {
    const user = userEvent.setup();
    render(<ControlledHarness />);
    const input = screen.getByRole('textbox', { hidden: true });
    await user.type(input, 'a1b2');
    expect((input as HTMLInputElement).value).toBe('12');
    expect(screen.getByText('1')).toBeInTheDocument();
    expect(screen.getByText('2')).toBeInTheDocument();
  });

  it('calls onComplete only once 6 digits have been entered', async () => {
    const user = userEvent.setup();
    const onComplete = vi.fn();
    render(<ControlledHarness onComplete={onComplete} />);
    const input = screen.getByRole('textbox', { hidden: true });
    await user.type(input, '12345');
    expect(onComplete).not.toHaveBeenCalled();
    await user.type(input, '6');
    expect(onComplete).toHaveBeenCalledWith('123456');
  });
});
