// @vitest-environment jsdom
import React from 'react';
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import {
  FOCUS_RING_CLASS,
  FOCUS_RING_DARK,
  FOCUS_RING_LIGHT,
  FOCUS_RING_OFFSET_PX,
  FOCUS_RING_WIDTH_PX,
} from '../../components/ui/focusRing';
import TextInput from '../../components/ui/TextInput';
import SelectField from '../../components/ui/SelectField';
import SearchField from '../../components/ui/SearchField';
import TextField from '../../components/admin-auth/TextField';

describe('focus.ring token (Ava TC-014)', () => {
  it('exports the design-token colours and 3px / 2px geometry', () => {
    expect(FOCUS_RING_LIGHT).toBe('#2346DD');
    expect(FOCUS_RING_DARK).toBe('#AFC3FF');
    expect(FOCUS_RING_WIDTH_PX).toBe(3);
    expect(FOCUS_RING_OFFSET_PX).toBe(2);
    expect(FOCUS_RING_CLASS).toContain('ring-[3px]');
    expect(FOCUS_RING_CLASS).toContain('ring-offset-2');
    expect(FOCUS_RING_CLASS).toContain(`ring-[${FOCUS_RING_LIGHT}]`);
    expect(FOCUS_RING_CLASS).toContain(`ring-[${FOCUS_RING_DARK}]`);
  });

  it('applies the focus-ring token on TextInput, SelectField, SearchField, TextField', () => {
    const { container, unmount } = render(
      <>
        <TextInput aria-label="name" />
        <SelectField aria-label="role" defaultValue="physician">
          <option value="physician">Physician</option>
        </SelectField>
        <SearchField aria-label="search people" placeholder="Search" />
        <TextField label="Email" />
      </>,
    );
    const name = container.querySelector('input[aria-label="name"]') as HTMLInputElement;
    const select = container.querySelector('select') as HTMLSelectElement;
    const search = container.querySelector('input[type="search"]') as HTMLInputElement;
    const email = container.querySelector('#Email, input[id]') as HTMLInputElement;
    // TextField generates an id — grab by label association
    const labeled = container.querySelectorAll('input');
    expect(name.className).toContain('ring-[#2346DD]');
    expect(name.className).toContain('ring-[3px]');
    expect(name.className).toContain('ring-offset-2');
    expect(select.className).toContain('ring-[#2346DD]');
    expect(search.className).toContain('ring-[#2346DD]');
    const textFieldInput = Array.from(labeled).find((el) => el !== name && el !== search)!;
    expect(textFieldInput.className).toContain('ring-[#2346DD]');
    expect(textFieldInput.className).toContain('dark:focus:ring-[#AFC3FF]');
    unmount();
  });
});
