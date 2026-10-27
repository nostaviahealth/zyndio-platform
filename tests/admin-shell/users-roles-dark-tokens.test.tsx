// @vitest-environment jsdom
// TC-013 dark surfaces: PreviewShell activates Tailwind `dark` class so
// shared UI `dark:` token classes apply; content must not inherit a forced
// light text color from the shell (that made Admin / selects invisible on
// the light table card).
import React from 'react';
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import PreviewShell from '../../pages/preview/PreviewShell';
import PageHeader from '../../components/ui/PageHeader';
import SearchField from '../../components/ui/SearchField';
import DataTable, { DataTableColumn } from '../../components/ui/DataTable';

describe('PreviewShell dark mode', () => {
  it('puts the Tailwind dark class on the root when mode is dark', () => {
    const { container } = render(
      <PreviewShell mode="dark">
        <div>content</div>
      </PreviewShell>
    );
    const root = container.firstElementChild as HTMLElement;
    expect(root.className.split(/\s+/)).toContain('dark');
    expect(root).toHaveAttribute('data-preview-theme', 'dark');
    expect(root.className).toMatch(/color-scheme:dark/);
  });

  it('does not force an inline light text color on main (dark)', () => {
    const { container } = render(
      <PreviewShell mode="dark">
        <span>child</span>
      </PreviewShell>
    );
    const main = container.querySelector('main');
    expect(main).toBeTruthy();
    expect(main!.getAttribute('style') || '').not.toMatch(/color/i);
  });
});

describe('Users & roles dark token classes', () => {
  it('PageHeader subtitle uses readable dark secondary text', () => {
    const { container } = render(
      <div className="dark">
        <PageHeader title="Users and roles" description="People at Zyndio who can sign in." />
      </div>
    );
    const desc = screen.getByText(/People at Zyndio/);
    expect(desc.className).toMatch(/dark:text-\[#A6B0C3\]/);
    const title = screen.getByRole('heading', { name: 'Users and roles' });
    expect(title.className).toMatch(/dark:text-\[#EEF1F8\]/);
    expect(container.querySelector('.dark')).toBeTruthy();
  });

  it('SearchField uses dark surface and placeholder tokens', () => {
    render(
      <div className="dark">
        <SearchField aria-label="Search by name or email" placeholder="Search by name or email" />
      </div>
    );
    const input = screen.getByLabelText('Search by name or email');
    expect(input.className).toMatch(/dark:bg-\[#10141F\]/);
    expect(input.className).toMatch(/dark:text-\[#EEF1F8\]/);
    expect(input.className).toMatch(/dark:placeholder:text-\[#8F9AAF\]/);
  });
});

describe('DataTable header casing (Ava)', () => {
  type Row = { id: string; name: string };
  const columns: DataTableColumn<Row>[] = [
    { key: 'name', header: 'Name', render: (r) => r.name },
    { key: 'role', header: 'Role', render: () => 'Admin' },
    { key: 'actions', header: '', render: () => null },
  ];

  it('renders sentence-case headers without uppercase class', () => {
    render(
      <DataTable
        columns={columns}
        rows={[{ id: '1', name: 'Taylor' }]}
        getRowId={(r) => r.id}
        caption="Users and roles"
      />
    );
    const nameTh = screen.getByRole('columnheader', { name: 'Name' });
    const roleTh = screen.getByRole('columnheader', { name: 'Role' });
    expect(nameTh.textContent).toBe('Name');
    expect(roleTh.textContent).toBe('Role');
    const row = nameTh.parentElement!;
    expect(row.className).not.toMatch(/uppercase/);
    expect(nameTh.className).not.toMatch(/uppercase/);
  });

  it('allows an empty Actions header label (design has no Actions title)', () => {
    render(
      <DataTable
        columns={columns}
        rows={[{ id: '1', name: 'Taylor' }]}
        getRowId={(r) => r.id}
      />
    );
    const headers = screen.getAllByRole('columnheader').map((h) => h.textContent);
    expect(headers).toEqual(['Name', 'Role', '']);
    expect(headers).not.toContain('Actions');
  });
});

describe('SelectField caret (Ava H2)', () => {
  it('renders a token-colored SVG caret on role and status selects', async () => {
    const { default: SelectField } = await import('../../components/ui/SelectField');
    const { container } = render(
      <div className="dark">
        <SelectField aria-label="Change role for alex@example.com" defaultValue="physician">
          <option value="physician">Physician</option>
        </SelectField>
        <SelectField aria-label="Filter by status" defaultValue="all">
          <option value="all">Status: All</option>
        </SelectField>
      </div>,
    );
    const role = screen.getByLabelText('Change role for alex@example.com');
    const status = screen.getByLabelText('Filter by status');
    expect(role.className).toMatch(/appearance-none/);
    expect(role.className).toMatch(/rounded-\[10px\]/);
    expect(status.className).toMatch(/rounded-\[10px\]/);
    expect(status.className).not.toMatch(/rounded-full/);
    const carets = container.querySelectorAll('[data-testid="select-caret"]');
    expect(carets.length).toBe(2);
    for (const caret of carets) {
      expect(caret.getAttribute('aria-hidden')).toBe('true');
      const cls = caret.getAttribute('class') ?? '';
      expect(cls).toMatch(/text-\[#48556A\]/);
      expect(cls).toMatch(/dark:text-\[#A6B0C3\]/);
      expect(caret.querySelector('path')?.getAttribute('d')).toBe('M6 9l6 6 6-6');
    }
  });
});
