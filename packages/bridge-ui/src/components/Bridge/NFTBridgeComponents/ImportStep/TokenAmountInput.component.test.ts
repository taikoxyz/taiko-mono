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

import { enteredAmount, selectedToken, tokenBalance } from '$components/Bridge/state';
import { fetchBalance, TokenType } from '$libs/token';
import { account } from '$stores/account';

import TokenAmountInput from './TokenAmountInput.svelte';

let target: HTMLElement;
let component: { $destroy: () => void; determineBalance: () => Promise<void> } | null = null;

const errorShown = () =>
  target.textContent?.includes('bridge.errors.no_decimals_allowed') ||
  target.textContent?.includes('bridge.errors.invalid_amount') ||
  false;

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
    expect(target.textContent).toContain('bridge.errors.no_decimals_allowed');
  });

  it('clears a previously accepted amount when exponent notation is entered', async () => {
    await type(input(), '5');
    await type(input(), '1e2');

    // Number inputs emit '1e2' natively; BigInt cannot parse it
    expect(get(enteredAmount)).toBe(BigInt(0));
  });

  it('clears the amount when the field is emptied, without complaining', async () => {
    await type(input(), '5');
    await type(input(), '');
    expect(get(enteredAmount)).toBe(BigInt(0));
    // A box nobody has filled in yet is not a mistake to report
    expect(errorShown()).toBe(false);
  });

  it('replaces a previous amount with a typed zero', async () => {
    // The zero-decimal path leaves nothing on either side of the scaling, so a parse that
    // threw here would escape inputAmount - which has no catch - and leave enteredAmount
    // holding the 5 while the box on screen reads 0, bridging an amount nobody asked for
    await type(input(), '5');
    expect(get(enteredAmount)).toBe(BigInt(5));

    await type(input(), '0');

    expect(get(enteredAmount)).toBe(BigInt(0));
    expect(errorShown()).toBe(false);
  });

  // Hex, exponent form and padding are covered in parseDecimalAmount.test.ts: a
  // type="number" field sanitizes them to an empty string before any handler sees them,
  // so asserting on them here would pass whatever the parsing does. What a number field
  // does pass through is a minus sign and an arbitrarily long digit string.
  describe('values that would be silently reinterpreted', () => {
    it('refuses a negative quantity', async () => {
      // BigInt('-5') is -5n, which no vault can transfer
      await type(input(), '-5');
      expect(get(enteredAmount)).toBe(BigInt(0));
      // and says so as an invalid amount, not as "decimals are not supported"
      expect(target.textContent).toContain('bridge.errors.invalid_amount');
    });

    it('refuses a quantity larger than a uint256', async () => {
      // BigInt is arbitrary precision, so this reached the vault call and reverted there
      await type(input(), '1'.repeat(80));
      expect(get(enteredAmount)).toBe(BigInt(0));
    });

    it('accepts the largest quantity a uint256 can carry', async () => {
      const max = BigInt(2) ** BigInt(256) - BigInt(1);
      await type(input(), max.toString());
      expect(get(enteredAmount)).toBe(max);
    });
  });
});

describe('balance reads that overlap', () => {
  it('lets only the newest read publish, so a slow read for the previous token cannot land', async () => {
    // Token A's balance read is slow; the user selects B and its read answers first. Left
    // unguarded, A's answer arrived last and showed A's balance under B's name - with
    // Continue enabled for a quantity B does not have.
    // determineBalance needs a connected account; the other tests never read a balance
    account.set({ address: '0x1111111111111111111111111111111111111111', isConnected: true } as never);
    tokenBalance.set(undefined as never);
    const mockedFetch = vi.mocked(fetchBalance);
    let resolveA!: (value: unknown) => void;
    mockedFetch.mockReturnValueOnce(new Promise((resolve) => (resolveA = resolve)) as never);
    const readA = component!.determineBalance();

    selectedToken.set({ type: TokenType.ERC1155, symbol: 'B', decimals: 0, addresses: {} } as never);
    mockedFetch.mockResolvedValueOnce({ value: BigInt(7), decimals: 0, symbol: 'B' } as never);
    await component!.determineBalance();
    expect(get(tokenBalance)?.value).toBe(BigInt(7));

    resolveA({ value: BigInt(1), decimals: 0, symbol: 'A' });
    await readA;

    expect(get(tokenBalance)?.value).toBe(BigInt(7));
  });
});
