/**
 * Typing in the page box must not move the list until the page is submitted.
 *
 * The box was bound straight to `currentPage`, which Transactions binds in turn, so an
 * emptied box made the list render page `null` and a typed 0 or negative a page that does
 * not exist - rows gone, "No transactions" shown - until blur ran the clamp.
 */
import { tick } from 'svelte';
import { vi } from 'vitest';

vi.mock('svelte-i18n', async () => {
  const { readable } = await import('svelte/store');
  return { t: readable((key: string) => key), locale: readable('en'), init: vi.fn(), addMessages: vi.fn() };
});

import PaginatorHost from '../../tests/PaginatorHost.svelte';

let target: HTMLElement;
let component: { $destroy: () => void; $set: (props: Record<string, unknown>) => void } | null = null;

const page = () => target.querySelector('[data-testid="page"]')?.textContent;
const box = () => target.querySelector('input[type="number"]') as HTMLInputElement;

const type = async (value: string) => {
  box().value = value;
  box().dispatchEvent(new Event('input', { bubbles: true }));
  await tick();
};

const blur = async () => {
  box().dispatchEvent(new Event('blur'));
  await tick();
};

const pressEnter = async () => {
  box().dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
  await tick();
};

beforeEach(() => {
  target = document.createElement('div');
  document.body.appendChild(target);
  // Twelve items, five per page: three pages, starting on the second
  component = new PaginatorHost({ target, props: { currentPage: 2, totalItems: 12, pageSize: 5 } });
});

afterEach(() => {
  component?.$destroy();
  component = null;
  target.remove();
});

describe('editing the page box', () => {
  it('leaves the page alone while the box is emptied', async () => {
    await type('');

    expect(page()).toBe('2');
  });

  it('leaves the page alone while a page that does not exist is typed', async () => {
    await type('0');
    expect(page()).toBe('2');

    await type('-1');
    expect(page()).toBe('2');

    await type('99');
    expect(page()).toBe('2');
  });

  it('moves to the typed page on Enter', async () => {
    await type('3');
    await pressEnter();

    expect(page()).toBe('3');
  });

  it('clamps an out-of-range page on blur and shows the page it landed on', async () => {
    await type('99');
    await blur();

    expect(page()).toBe('3');
    expect(box().value).toBe('3');
  });

  it('falls back to the first page when the box is left empty', async () => {
    await type('');
    await blur();

    expect(page()).toBe('1');
    expect(box().value).toBe('1');
  });

  it('follows a page change made by the parent', async () => {
    component!.$set({ currentPage: 3 });
    await tick();

    expect(box().value).toBe('3');
  });
});
