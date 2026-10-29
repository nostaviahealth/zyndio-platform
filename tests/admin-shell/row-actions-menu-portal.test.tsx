// @vitest-environment jsdom
// TC-019 fix round, Ava F1 (High) on a0e5ddd: the ··· menu rendered inside the
// pinned (position: sticky) actions cell of a table wrapped in overflow-x-auto,
// so later rows painted over it and the scroll card clipped it (last row: ~8px
// visible). The menu must render outside the table (portal on document.body),
// fixed-positioned against the trigger, open upward when there is no room
// below, stay keyboard-usable, and close on scroll/resize.
// The real-browser hit-test (every item of the LAST row's menu visible and
// clicked, 1024 + 1440, both themes) is in scripts/tc019_theme_check.py.
import React from 'react';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import RowActionsMenu, { type RowActionItem } from '../../components/ui/RowActionsMenu';

const VIEW_W = 1024;
const VIEW_H = 768;
const MENU_H = 3 * 44 + 8;

function rect(left: number, top: number, width: number, height: number): DOMRect {
  return {
    left, top, width, height, right: left + width, bottom: top + height, x: left, y: top,
    toJSON: () => ({}),
  } as DOMRect;
}

let triggerRect = rect(900, 100, 44, 44);

function renderInStickyTable(items: RowActionItem[]) {
  return render(
    <div className="overflow-x-auto" data-testid="scroller">
      <table>
        <tbody>
          <tr>
            <td>Row</td>
            <td className="sticky right-0">
              <RowActionsMenu email="last.row@example.test" items={items} />
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  );
}

function threeItems() {
  return [
    { label: 'Request two-factor reset', onClick: vi.fn() },
    { label: 'Deactivate', onClick: vi.fn(), destructive: true },
    { label: 'Cancel invite', onClick: vi.fn(), destructive: true },
  ];
}

beforeEach(() => {
  Object.defineProperty(window, 'innerWidth', { configurable: true, value: VIEW_W });
  Object.defineProperty(window, 'innerHeight', { configurable: true, value: VIEW_H });
  vi.spyOn(HTMLElement.prototype, 'getBoundingClientRect').mockImplementation(function (this: HTMLElement) {
    if (this.getAttribute('role') === 'menu') return rect(0, 0, 224, MENU_H);
    if (this.getAttribute('aria-haspopup') === 'menu') return triggerRect;
    return rect(0, 0, 0, 0);
  });
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe('RowActionsMenu renders outside the table (Ava F1)', () => {
  it('portals the open menu to document.body with fixed positioning', async () => {
    const user = userEvent.setup();
    renderInStickyTable(threeItems());
    await user.click(screen.getByRole('button', { name: 'More actions for last.row@example.test' }));
    const menu = screen.getByRole('menu');
    expect(menu.closest('table')).toBeNull();
    expect(menu.closest('[data-testid="scroller"]')).toBeNull();
    expect(menu.parentElement).toBe(document.body);
    expect(menu.style.position).toBe('fixed');
  });

  it('opens below the trigger, right-aligned to it, when there is room below', async () => {
    triggerRect = rect(900, 100, 44, 44);
    const user = userEvent.setup();
    renderInStickyTable(threeItems());
    await user.click(screen.getByRole('button', { name: /More actions/ }));
    const menu = screen.getByRole('menu');
    expect(menu.style.top).toBe(`${100 + 44 + 4}px`);
    expect(menu.style.bottom).toBe('');
    expect(menu.style.right).toBe(`${VIEW_W - (900 + 44)}px`);
  });

  it('opens upward when there is no room below (last row near the bottom)', async () => {
    triggerRect = rect(900, 700, 44, 44);
    const user = userEvent.setup();
    renderInStickyTable(threeItems());
    await user.click(screen.getByRole('button', { name: /More actions/ }));
    const menu = screen.getByRole('menu');
    expect(menu.style.top).toBe('');
    expect(menu.style.bottom).toBe(`${VIEW_H - 700 + 4}px`);
  });
});

describe('RowActionsMenu keyboard, Escape, scroll and resize (Ava F1)', () => {
  beforeEach(() => {
    triggerRect = rect(900, 100, 44, 44);
  });

  it('Enter opens and focuses the first item, arrows move, Escape closes and refocuses the trigger', async () => {
    const user = userEvent.setup();
    renderInStickyTable(threeItems());
    const trigger = screen.getByRole('button', { name: /More actions/ });
    trigger.focus();
    await user.keyboard('{Enter}');
    const items = screen.getAllByRole('menuitem');
    expect(items[0]).toHaveFocus();
    await user.keyboard('{ArrowDown}');
    expect(items[1]).toHaveFocus();
    await user.keyboard('{ArrowUp}{ArrowUp}');
    expect(items[2]).toHaveFocus();
    await user.keyboard('{Escape}');
    expect(screen.queryByRole('menu')).toBeNull();
    expect(trigger).toHaveFocus();
  });

  it('Tab out of the menu closes it and returns focus to the trigger', async () => {
    const user = userEvent.setup();
    renderInStickyTable(threeItems());
    const trigger = screen.getByRole('button', { name: /More actions/ });
    await user.click(trigger);
    await user.keyboard('{Tab}');
    expect(screen.queryByRole('menu')).toBeNull();
    expect(trigger).toHaveFocus();
  });

  it('closes when the page or the table scroller scrolls', async () => {
    const user = userEvent.setup();
    renderInStickyTable(threeItems());
    await user.click(screen.getByRole('button', { name: /More actions/ }));
    expect(screen.getByRole('menu')).toBeInTheDocument();
    fireEvent.scroll(screen.getByTestId('scroller'));
    expect(screen.queryByRole('menu')).toBeNull();

    await user.click(screen.getByRole('button', { name: /More actions/ }));
    fireEvent.scroll(window);
    expect(screen.queryByRole('menu')).toBeNull();
  });

  it('closes on window resize', async () => {
    const user = userEvent.setup();
    renderInStickyTable(threeItems());
    await user.click(screen.getByRole('button', { name: /More actions/ }));
    fireEvent(window, new Event('resize'));
    expect(screen.queryByRole('menu')).toBeNull();
  });

  it('closes on a click outside, but not on a click inside the menu panel', async () => {
    const user = userEvent.setup();
    renderInStickyTable(threeItems());
    await user.click(screen.getByRole('button', { name: /More actions/ }));
    await user.click(screen.getByRole('menu'));
    expect(screen.getByRole('menu')).toBeInTheDocument();
    await user.click(document.body);
    expect(screen.queryByRole('menu')).toBeNull();
  });

  it('every item is clickable from the portal and runs its action once', async () => {
    const user = userEvent.setup();
    const items = threeItems();
    renderInStickyTable(items);
    for (const item of items) {
      await user.click(screen.getByRole('button', { name: /More actions/ }));
      await user.click(screen.getByRole('menuitem', { name: item.label }));
      expect(item.onClick).toHaveBeenCalledTimes(1);
      expect(screen.queryByRole('menu')).toBeNull();
    }
  });
});
