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

const getMaxAmountToBridge = vi.fn();
vi.mock('$libs/bridge', async (importOriginal) => ({
  ...(await importOriginal<typeof import('$libs/bridge')>()),
  getMaxAmountToBridge: (...args: unknown[]) => getMaxAmountToBridge(...args),
}));

import {
  computingBalance,
  destNetwork,
  enteredAmount,
  errorComputingBalance,
  insufficientBalance,
  selectedToken,
  tokenBalance,
} from '$components/Bridge/state';
import { TokenType } from '$libs/token';
import { account } from '$stores/account';
import { ethBalance } from '$stores/balance';
import { connectedSourceChain } from '$stores/network';

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

describe('token switching', () => {
  const dai = { type: TokenType.ERC20, symbol: 'DAI', name: 'DAI', decimals: 18, addresses: {} };

  const flush = async () => {
    await new Promise((resolve) => setTimeout(resolve, 0));
    await tick();
  };

  it('still resets when switching back to a token whose reset was superseded', async () => {
    const USER = '0x1111111111111111111111111111111111111111';
    account.set({ address: USER, isConnected: true, chainId: 1 } as never);
    await tick();
    await flush();

    // Switch to an 18-decimal token whose balance read hangs
    let resolveSlow!: (value: unknown) => void;
    fetchBalance.mockReturnValueOnce(new Promise((resolve) => (resolveSlow = resolve)));
    selectedToken.set(dai as never);
    await tick();

    // A chain switch emits an account event carrying the same address, which takes the
    // refresh branch and supersedes the reset still in flight. previousSelectedToken used
    // to be recorded only after the reset's own read won, so it was never updated here.
    fetchBalance.mockResolvedValue({ value: BigInt(0), decimals: 18, symbol: 'DAI', formatted: '0' });
    account.set({ address: USER, isConnected: true, chainId: 167000 } as never);
    await flush();
    resolveSlow({ value: BigInt(0), decimals: 18, symbol: 'DAI', formatted: '0' });
    await flush();

    // The amount belongs to the token on screen: with previousSelectedToken left describing
    // the earlier one, the box and the store stop agreeing about which token this is for
    await type('2.5');
    expect(get(enteredAmount)).toBe(BigInt('2500000000000000000'));

    // Back to the six-decimal token: the reset must run, or the box keeps DAI's amount and
    // an 18-decimal raw value is validated and bridged as USDC
    fetchBalance.mockResolvedValue({ value: BigInt(0), decimals: 6, symbol: 'USDC', formatted: '0' });
    selectedToken.set(usdc as never);
    await flush();

    expect(get(enteredAmount)).toBe(BigInt(0));
    expect((target.querySelector('input') as HTMLInputElement).value).toBe('');
  });
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

    it('stops computing when the balance read fails', async () => {
      account.set({ address: '0xaaaa', isConnected: true, chainId: 1 } as never);
      await new Promise((resolve) => setTimeout(resolve, 0));
      await tick();

      const token = { type: TokenType.ERC20, symbol: 'X', name: 'X', decimals: 18, addresses: {} };
      fetchBalance.mockRejectedValueOnce(new Error('rpc down'));
      selectedToken.set(token as never);
      await new Promise((resolve) => setTimeout(resolve, 0));
      await tick();

      // Without a catch this escapes as an unhandled rejection and the spinner never stops
      expect(get(computingBalance)).toBe(false);
      expect(get(errorComputingBalance)).toBe(true);
    });

    it('does not let a superseded failing read raise the error flag', async () => {
      account.set({ address: '0xaaaa', isConnected: true, chainId: 1 } as never);
      await new Promise((resolve) => setTimeout(resolve, 0));
      await tick();

      // A slow read for token A fails after the user has already moved to token B, whose
      // balance loaded fine. The failure describes a token no longer on screen
      let failSlowRead: (error: Error) => void = () => undefined;
      fetchBalance.mockReturnValueOnce(new Promise((_, reject) => (failSlowRead = reject)));
      selectedToken.set({ type: TokenType.ERC20, symbol: 'A', name: 'A', decimals: 18, addresses: {} } as never);
      await tick();

      fetchBalance.mockResolvedValueOnce({ value: BigInt(9), decimals: 18, symbol: 'B', formatted: '9' });
      selectedToken.set({ type: TokenType.ERC20, symbol: 'B', name: 'B', decimals: 18, addresses: {} } as never);
      await new Promise((resolve) => setTimeout(resolve, 0));
      await tick();

      failSlowRead(new Error('rpc down'));
      await new Promise((resolve) => setTimeout(resolve, 0));
      await tick();

      expect(get(errorComputingBalance)).toBe(false);
      expect(get(tokenBalance)).toEqual({ value: BigInt(9), decimals: 18, symbol: 'B', formatted: '9' });
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

describe('an amount above the balance', () => {
  /** validateAmount is debounced by 300ms behind the input event */
  const settle = async () => {
    await new Promise((resolve) => setTimeout(resolve, 350));
    await tick();
  };

  beforeEach(() => {
    // Everything skipValidate wants before it lets the check run. The connected account
    // also triggers the component's own balance read, so the mock has to answer with the
    // same balance the test seeds, or the read overwrites it with the default zero.
    fetchBalance.mockResolvedValue({ value: BigInt(5_000_000), decimals: 6, symbol: 'USDC', formatted: '5' });
    account.set({ address: '0x1111111111111111111111111111111111111111', isConnected: true } as never);
    connectedSourceChain.set({ id: 1 } as never);
    destNetwork.set({ id: 2 } as never);
    ethBalance.set(BigInt(1));
    tokenBalance.set({ value: BigInt(5_000_000), decimals: 6, symbol: 'USDC', formatted: '5' } as never);
    insufficientBalance.set(false);
  });

  it('is refused, and the refusal clears once the amount fits', async () => {
    // The check lived in a helper nothing called, so the alert was dead and the Confirm
    // step's Bridge button - gated on the same flag - never learned the wallet was short
    await type('10');
    await settle();
    expect(get(enteredAmount)).toBe(BigInt(10_000_000));
    expect(get(insufficientBalance)).toBe(true);

    await type('3');
    await settle();
    expect(get(insufficientBalance)).toBe(false);
  });
});

describe('the MAX button', () => {
  const dai = { type: TokenType.ERC20, symbol: 'DAI', name: 'DAI', decimals: 18, addresses: {} };

  const flush = async () => {
    await new Promise((resolve) => setTimeout(resolve, 0));
    await tick();
  };

  const inputValue = () => (target.querySelector('input') as HTMLInputElement).value;

  const clickMax = async () => {
    (target.querySelector('button.max-button') as HTMLButtonElement).click();
    await tick();
  };

  beforeEach(async () => {
    fetchBalance.mockResolvedValue({ value: BigInt(5_000_000), decimals: 6, symbol: 'USDC', formatted: '5' });
    account.set({ address: '0x1111111111111111111111111111111111111111', isConnected: true } as never);
    connectedSourceChain.set({ id: 1 } as never);
    destNetwork.set({ id: 2 } as never);
    ethBalance.set(BigInt(1));
    // Connecting starts a balance read that keeps the button disabled until it lands
    await flush();
  });

  it('fills in the maximum for the selected token', async () => {
    getMaxAmountToBridge.mockResolvedValue(BigInt(5_000_000));

    await clickMax();
    await flush();

    expect(inputValue()).toBe('5');
    expect(get(enteredAmount)).toBe(BigInt(5_000_000));
  });

  it('drops a maximum computed for a token the user has since switched away from', async () => {
    let resolveMax!: (value: bigint) => void;
    getMaxAmountToBridge.mockReturnValueOnce(new Promise<bigint>((resolve) => (resolveMax = resolve)));
    await clickMax();

    // The estimate is still running when the user picks an 18-decimal token
    fetchBalance.mockResolvedValue({ value: BigInt(0), decimals: 18, symbol: 'DAI', formatted: '0' });
    selectedToken.set(dai as never);
    await flush();

    // 100 USDC in USDC's raw units lands after the switch. Formatted with DAI's decimals it
    // showed as 0.0000000001, while the bigint that would be bridged was the USDC maximum
    resolveMax(BigInt(100_000_000));
    await flush();

    expect(get(enteredAmount)).toBe(BigInt(0));
    expect(inputValue()).toBe('');
  });

  it('drops a maximum computed for a route the user has since changed', async () => {
    let resolveMax!: (value: bigint) => void;
    getMaxAmountToBridge.mockReturnValueOnce(new Promise<bigint>((resolve) => (resolveMax = resolve)));
    await clickMax();

    // Nothing else notices a destination change - no reset runs for it - so the estimate,
    // which reserved gas for the route it was asked about, is only caught here
    destNetwork.set({ id: 3 } as never);
    await tick();

    resolveMax(BigInt(5_000_000));
    await flush();

    expect(get(enteredAmount)).toBe(BigInt(0));
    expect(inputValue()).toBe('');
  });

  it('drops a maximum started by an earlier instance of this step', async () => {
    // Continuing to the review step and coming back mounts a new input while the old one's
    // estimate is still out, and both write the shared amount store
    let resolveMax!: (value: bigint) => void;
    getMaxAmountToBridge.mockReturnValueOnce(new Promise<bigint>((resolve) => (resolveMax = resolve)));
    await clickMax();

    component?.$destroy();
    target.remove();
    target = document.createElement('div');
    document.body.appendChild(target);
    component = new TokenInput({ target, props: {} });
    await flush();
    await type('3');

    resolveMax(BigInt(5_000_000));
    await flush();

    expect(get(enteredAmount)).toBe(BigInt(3_000_000));
    expect(inputValue()).toBe('3');
  });

  it('lets an amount typed while the maximum was being computed stand', async () => {
    let resolveMax!: (value: bigint) => void;
    getMaxAmountToBridge.mockReturnValueOnce(new Promise<bigint>((resolve) => (resolveMax = resolve)));
    await clickMax();

    await type('3');

    resolveMax(BigInt(5_000_000));
    await flush();

    // The later of the two actions is the one the user meant
    expect(get(enteredAmount)).toBe(BigInt(3_000_000));
    expect(inputValue()).toBe('3');
  });
});
