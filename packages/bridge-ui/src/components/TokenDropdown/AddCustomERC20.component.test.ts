/**
 * A token lookup must not publish under an address the user has already replaced.
 *
 * AddressInput dispatches nothing for a cleared field or text without a `0x` prefix, so
 * an edit can leave no validation event behind and the generation counter is never
 * advanced. The two-way bound draft is the only remaining signal.
 */
import { tick } from 'svelte';
import { vi } from 'vitest';

vi.mock('svelte-i18n', async () => {
  const { readable } = await import('svelte/store');
  return { t: readable((key: string) => key), locale: readable('en'), init: vi.fn(), addMessages: vi.fn() };
});

const detectContractType = vi.fn();
const getTokenWithInfoFromAddress = vi.fn();

vi.mock('@wagmi/core');
vi.mock('$libs/token', async (importOriginal) => ({
  ...(await importOriginal<typeof import('$libs/token')>()),
  detectContractType: (...a: unknown[]) => detectContractType(...a),
}));
vi.mock('$libs/token/getTokenWithInfoFromAddress', () => ({
  getTokenWithInfoFromAddress: (...a: unknown[]) => getTokenWithInfoFromAddress(...a),
}));

import { readContract } from '@wagmi/core';

import { TokenType } from '$libs/token';
import { account } from '$stores/account';
import { connectedSourceChain } from '$stores/network';

import AddCustomERC20 from './AddCustomERC20.svelte';

const ADDRESS_A = '0x1111111111111111111111111111111111111111';

let target: HTMLElement;
let component: { $destroy: () => void } | null = null;

const flush = async () => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  await tick();
};

const addressInput = () => target.querySelector('input') as HTMLInputElement;

const type = async (value: string) => {
  const input = addressInput();
  input.value = value;
  input.dispatchEvent(new Event('input', { bubbles: true }));
  await tick();
};

/** The resolved-token panel shows the symbol; absent means nothing is being offered */
const showsToken = () => (target.textContent ?? '').includes('MOCK');

beforeEach(() => {
  detectContractType.mockReset();
  getTokenWithInfoFromAddress.mockReset();
  vi.mocked(readContract)
    .mockReset()
    .mockResolvedValue(BigInt(1) as never);
  connectedSourceChain.set({ id: 1 } as never);
  account.set({ address: '0xaaaa', isConnected: true } as never);
  target = document.createElement('div');
  document.body.appendChild(target);
  component = new AddCustomERC20({ target, props: {} });
});

afterEach(() => {
  component?.$destroy();
  component = null;
  target.remove();
});

describe('custom ERC20 lookup', () => {
  it('offers a token once its lookup resolves', async () => {
    detectContractType.mockResolvedValue(TokenType.ERC20);
    getTokenWithInfoFromAddress.mockResolvedValue({ symbol: 'MOCK', decimals: 18, addresses: {} });

    await type(ADDRESS_A);
    await flush();

    expect(showsToken()).toBe(true);
  });

  it('discards a lookup whose address was cleared while it was pending', async () => {
    detectContractType.mockResolvedValue(TokenType.ERC20);
    let resolveToken!: (value: unknown) => void;
    getTokenWithInfoFromAddress.mockReturnValue(new Promise((resolve) => (resolveToken = resolve)));

    await type(ADDRESS_A);
    await tick();

    // Clearing the field dispatches no validation event at all
    await type('');
    resolveToken({ symbol: 'MOCK', decimals: 18, addresses: {} });
    await flush();

    expect(showsToken()).toBe(false);
  });

  it('discards a lookup when the address is replaced by text that dispatches nothing', async () => {
    detectContractType.mockResolvedValue(TokenType.ERC20);
    let resolveToken!: (value: unknown) => void;
    getTokenWithInfoFromAddress.mockReturnValue(new Promise((resolve) => (resolveToken = resolve)));

    await type(ADDRESS_A);
    await tick();

    // Text without a `0x` prefix: AddressInput marks it invalid but stays silent
    await type('abc');
    resolveToken({ symbol: 'MOCK', decimals: 18, addresses: {} });
    await flush();

    expect(showsToken()).toBe(false);
  });

  it('stops offering a resolved token once the address is cleared', async () => {
    detectContractType.mockResolvedValue(TokenType.ERC20);
    getTokenWithInfoFromAddress.mockResolvedValue({ symbol: 'MOCK', decimals: 18, addresses: {} });

    await type(ADDRESS_A);
    await flush();
    expect(showsToken()).toBe(true);

    // A finished lookup leaves nothing pending, and clearing the field dispatches no
    // event: the form kept offering a token for an address no longer on screen
    await type('');
    await flush();

    expect(showsToken()).toBe(false);
  });

  describe('source chain changes', () => {
    it('resolves the token against the chain the lookup started on', async () => {
      detectContractType.mockResolvedValue(TokenType.ERC20);
      let resolveToken!: (value: unknown) => void;
      getTokenWithInfoFromAddress.mockReturnValue(new Promise((resolve) => (resolveToken = resolve)));

      await type(ADDRESS_A);
      await flush();

      // Not the chain that happens to be selected by the time the await lands
      expect(detectContractType).toHaveBeenCalledWith(ADDRESS_A, 1);
      expect(getTokenWithInfoFromAddress).toHaveBeenCalledWith(
        expect.objectContaining({ contractAddress: ADDRESS_A, srcChainId: 1 }),
      );
      resolveToken(null);
    });

    it('drops a lookup that was started on the previous chain', async () => {
      detectContractType.mockResolvedValue(TokenType.ERC20);
      let resolveToken!: (value: unknown) => void;
      getTokenWithInfoFromAddress.mockReturnValue(new Promise((resolve) => (resolveToken = resolve)));

      await type(ADDRESS_A);
      await tick();

      // The same address is a different contract on a different chain
      connectedSourceChain.set({ id: 2 } as never);
      await tick();
      resolveToken({ symbol: 'MOCK', decimals: 18, addresses: {} });
      await flush();

      expect(showsToken()).toBe(false);
    });

    it('drops a token that already resolved against the previous chain', async () => {
      detectContractType.mockResolvedValue(TokenType.ERC20);
      getTokenWithInfoFromAddress.mockResolvedValue({ symbol: 'MOCK', decimals: 18, addresses: {} });

      await type(ADDRESS_A);
      await flush();
      expect(showsToken()).toBe(true);

      connectedSourceChain.set({ id: 2 } as never);
      await flush();

      expect(showsToken()).toBe(false);
    });
  });
});
