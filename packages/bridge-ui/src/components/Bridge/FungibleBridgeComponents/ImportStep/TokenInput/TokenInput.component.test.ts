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

const fetchBalance = vi.fn();
vi.mock('$libs/token', async (importOriginal) => ({
  ...(await importOriginal<typeof import('$libs/token')>()),
  fetchBalance: (...args: unknown[]) => fetchBalance(...args),
}));

// Both reach into the automocked @wagmi/core, which has no usable getAccount, and the
// balance reset path calls them on every token switch
vi.mock('$libs/util/balance', () => ({
  refreshUserBalance: vi.fn().mockResolvedValue(undefined),
  renderBalance: (balance: { formatted?: string; symbol?: string } | null | undefined) =>
    balance ? `${balance.formatted ?? '0'} ${balance.symbol ?? ''}` : '0.00',
  renderEthBalance: () => '0 ETH',
}));

import { computingBalance, enteredAmount, selectedToken, tokenBalance } from '$components/Bridge/state';
import { TokenType } from '$libs/token';
import { account } from '$stores/account';

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
  fetchBalance.mockReset().mockResolvedValue({ value: BigInt(0), decimals: 6, symbol: 'USDC', formatted: '0' });
  enteredAmount.set(BigInt(0));
  tokenBalance.set(undefined as never);
  // Disconnected at mount, so the only balance reads in a test are the ones it makes:
  // the account store is module-level and otherwise carries over between tests
  account.set({ isConnected: false } as never);
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

  describe('balance reads', () => {
    it("does not let a slow token switch overwrite a newer token's balance", async () => {
      account.set({ address: '0xaaaa', isConnected: true } as never);
      // Connecting triggers its own balance read; let it settle so the race below is
      // between the two token switches and nothing else
      await new Promise((resolve) => setTimeout(resolve, 0));
      await tick();

      const slow = { type: TokenType.ERC20, symbol: 'SLOW', name: 'Slow', decimals: 18, addresses: {} };
      const fast = { type: TokenType.ERC20, symbol: 'FAST', name: 'Fast', decimals: 18, addresses: {} };

      let resolveSlow!: (value: unknown) => void;
      fetchBalance.mockReturnValueOnce(new Promise((resolve) => (resolveSlow = resolve)));
      selectedToken.set(slow as never);
      await tick();

      // A second switch, whose read answers first
      fetchBalance.mockResolvedValueOnce({ value: BigInt(5), decimals: 18, symbol: 'FAST', formatted: '5' });
      selectedToken.set(fast as never);
      await new Promise((resolve) => setTimeout(resolve, 0));
      await tick();

      // The earlier read lands late. Publishing it would validate amounts against SLOW's
      // balance while FAST is selected, and walk the user through an approval for an
      // amount they do not hold
      resolveSlow({ value: BigInt(999), decimals: 18, symbol: 'SLOW', formatted: '999' });
      await new Promise((resolve) => setTimeout(resolve, 0));
      await tick();

      // Whatever the interleaving, the balance on screen belongs to the selected token
      expect(get(tokenBalance)).toEqual({ value: BigInt(5), decimals: 18, symbol: 'FAST', formatted: '5' });
    });

    it('stops computing when an account change supersedes an in-flight reset', async () => {
      account.set({ address: '0xaaaa', isConnected: true, chainId: 1 } as never);
      await new Promise((resolve) => setTimeout(resolve, 0));
      await tick();

      // A token switch starts a read that will not answer for a while
      const slow = { type: TokenType.ERC20, symbol: 'SLOW', name: 'Slow', decimals: 18, addresses: {} };
      let resolveSlow!: (value: unknown) => void;
      fetchBalance.mockReturnValueOnce(new Promise((resolve) => (resolveSlow = resolve)));
      selectedToken.set(slow as never);
      await tick();

      // The same account on another chain takes the other branch of onAccountChange,
      // which reads the balance without going through reset
      fetchBalance.mockResolvedValueOnce({ value: BigInt(7), decimals: 18, symbol: 'SLOW', formatted: '7' });
      account.set({ address: '0xaaaa', isConnected: true, chainId: 2 } as never);
      await new Promise((resolve) => setTimeout(resolve, 0));
      await tick();

      resolveSlow({ value: BigInt(999), decimals: 18, symbol: 'SLOW', formatted: '999' });
      await new Promise((resolve) => setTimeout(resolve, 0));
      await tick();

      // The superseded reset declines to clear this, so the read that superseded it must
      expect(get(computingBalance)).toBe(false);
    });
  });
});
