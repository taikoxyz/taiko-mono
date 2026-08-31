/**
 * ERC-1155 amounts: invalid input must not leave the previously entered amount behind.
 *
 * Both import flows gate Continue on `$enteredAmount > 0`, so an amount that survives the
 * input it was replaced by is an amount the user can still bridge without seeing it.
 */
import { tick } from 'svelte';
import { get } from 'svelte/store';
import { vi } from 'vitest';

vi.mock('svelte-i18n', async () => {
  const { readable } = await import('svelte/store');
  return { t: readable((key: string) => key), locale: readable('en'), init: vi.fn(), addMessages: vi.fn() };
});

vi.mock('$libs/token', async (importOriginal) => ({
  ...(await importOriginal<typeof import('$libs/token')>()),
  fetchBalance: vi.fn().mockResolvedValue({ value: BigInt(100), decimals: 0, symbol: 'NFT' }),
}));

import { enteredAmount, selectedToken } from '$components/Bridge/state';
import { TokenType } from '$libs/token';

import TokenAmountInput from './TokenAmountInput.svelte';

let target: HTMLElement;
let component: { $destroy: () => void } | null = null;

const type = async (input: HTMLInputElement, value: string) => {
  input.value = value;
  input.dispatchEvent(new Event('input', { bubbles: true }));
  await tick();
};

beforeEach(() => {
  enteredAmount.set(BigInt(0));
  selectedToken.set({ type: TokenType.ERC1155, symbol: 'NFT', decimals: 0, addresses: {} } as never);
  target = document.createElement('div');
  document.body.appendChild(target);
  component = new TokenAmountInput({ target, props: {} });
});

afterEach(() => {
  component?.$destroy();
  component = null;
  target.remove();
});

describe('ERC1155 amount input', () => {
  const input = () => target.querySelector('input') as HTMLInputElement;

  it('accepts a whole number', async () => {
    await type(input(), '5');
    expect(get(enteredAmount)).toBe(BigInt(5));
  });

  it('clears a previously accepted amount when a decimal is entered', async () => {
    await type(input(), '5');
    expect(get(enteredAmount)).toBe(BigInt(5));

    await type(input(), '1.5');

    // Leaving 5n here would bridge 5 while the box reads 1.5
    expect(get(enteredAmount)).toBe(BigInt(0));
  });

  it('clears a previously accepted amount when exponent notation is entered', async () => {
    await type(input(), '5');
    await type(input(), '1e2');

    // Number inputs emit '1e2' natively; BigInt cannot parse it
    expect(get(enteredAmount)).toBe(BigInt(0));
  });

  it('clears the amount when the field is emptied', async () => {
    await type(input(), '5');
    await type(input(), '');
    expect(get(enteredAmount)).toBe(BigInt(0));
  });
});
