/**
 * Fungible amounts: an amount that cannot be parsed exactly must not become a different
 * amount, and must say so on screen.
 *
 * `parseUnits` on its own is happy to round `1.2345678` down to a 6-decimal token's
 * precision and to take a leading minus sign, so the box could carry one number while the
 * bridge carried another. The parsing rules themselves are covered in
 * parseDecimalAmount.test.ts; this covers the wiring - the store, and the message.
 */
import { tick } from 'svelte';
import { get } from 'svelte/store';
import { vi } from 'vitest';

window.matchMedia = vi.fn().mockReturnValue({
  matches: true,
  addEventListener: vi.fn(),
  removeEventListener: vi.fn(),
}) as never;

vi.mock('svelte-i18n', async () => {
  const { readable } = await import('svelte/store');
  return { t: readable((key: string) => key), locale: readable('en'), init: vi.fn(), addMessages: vi.fn() };
});

// The dropdown pulls in the whole token list and a media-query component, none of which
// the amount box needs
vi.mock('$components/TokenDropdown', async () => ({
  TokenDropdown: (await import('../../../../../tests/StubComponent.svelte')).default,
}));

import { enteredAmount, selectedToken } from '$components/Bridge/state';
import { TokenType } from '$libs/token';

import TokenInput from './TokenInput.svelte';

let target: HTMLElement;
let component: { $destroy: () => void } | null = null;

const type = async (value: string) => {
  const input = target.querySelector('input') as HTMLInputElement;
  input.value = value;
  input.dispatchEvent(new Event('input', { bubbles: true }));
  await tick();
};

const errorShown = () => target.textContent?.includes('bridge.errors.invalid_amount') ?? false;

/** A six-decimal token, so excess precision is reachable with a short string */
const usdc = { type: TokenType.ERC20, symbol: 'USDC', name: 'USDC', decimals: 6, addresses: {} };

beforeEach(() => {
  enteredAmount.set(BigInt(0));
  selectedToken.set(usdc as never);
  target = document.createElement('div');
  document.body.appendChild(target);
  component = new TokenInput({ target, props: {} });
});

afterEach(() => {
  component?.$destroy();
  component = null;
  target.remove();
});

describe('fungible amount input', () => {
  it('accepts an amount at the token precision', async () => {
    await type('1.234567');
    expect(get(enteredAmount)).toBe(BigInt(1234567));
    expect(errorShown()).toBe(false);
  });

  it('refuses more precision than the token has, rather than rounding it', async () => {
    // parseUnits('1.2345678', 6) is 1234568 - a hundredth of a cent more than was typed,
    // with nothing on screen saying so
    await type('1.2345678');
    expect(get(enteredAmount)).toBe(BigInt(0));
    expect(errorShown()).toBe(true);
  });

  it('refuses a negative amount', async () => {
    // parseUnits('-5', 6) is -5000000
    await type('-5');
    expect(get(enteredAmount)).toBe(BigInt(0));
    expect(errorShown()).toBe(true);
  });

  it('refuses an amount larger than a uint256', async () => {
    await type('1'.repeat(80));
    expect(get(enteredAmount)).toBe(BigInt(0));
    expect(errorShown()).toBe(true);
  });

  it('clears a previously accepted amount when the entry becomes invalid', async () => {
    await type('2');
    expect(get(enteredAmount)).toBe(BigInt(2000000));

    await type('2.0000001');

    // Leaving 2000000n here would bridge 2 while the box reads 2.0000001
    expect(get(enteredAmount)).toBe(BigInt(0));
  });

  it('treats an emptied field as untouched, not as an error', async () => {
    await type('2');
    await type('');
    expect(get(enteredAmount)).toBe(BigInt(0));
    expect(errorShown()).toBe(false);
  });

  it('drops the error once a valid amount is entered', async () => {
    await type('-5');
    expect(errorShown()).toBe(true);

    await type('3');
    expect(get(enteredAmount)).toBe(BigInt(3000000));
    expect(errorShown()).toBe(false);
  });
});
