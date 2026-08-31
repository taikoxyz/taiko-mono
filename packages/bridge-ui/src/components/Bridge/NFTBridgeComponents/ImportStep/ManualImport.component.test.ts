/**
 * A contract-type lookup describes one address on one chain.
 *
 * Without a generation guard, a lookup for an address typed earlier can resolve after a
 * newer one and re-enable the id field with the wrong type for the address on screen.
 * AddressInput also dispatches nothing for a cleared field, so the two-way bound draft is
 * the only signal that a pending lookup has been abandoned.
 */
import { tick } from 'svelte';
import { get } from 'svelte/store';
import { vi } from 'vitest';

vi.mock('svelte-i18n', async () => {
  const { readable } = await import('svelte/store');
  return { t: readable((key: string) => key), locale: readable('en'), init: vi.fn(), addMessages: vi.fn() };
});

const detectContractType = vi.fn();
const checkOwnership = vi.fn();
const getTokenWithInfoFromAddress = vi.fn();

vi.mock('$libs/token', async (importOriginal) => ({
  ...(await importOriginal<typeof import('$libs/token')>()),
  detectContractType: (...args: unknown[]) => detectContractType(...args),
  fetchBalance: vi.fn().mockResolvedValue({ value: BigInt(10), decimals: 0, symbol: 'NFT' }),
}));
vi.mock('$libs/token/checkOwnership', () => ({ checkOwnership: (...a: unknown[]) => checkOwnership(...a) }));
vi.mock('$libs/token/getTokenWithInfoFromAddress', () => ({
  getTokenWithInfoFromAddress: (...a: unknown[]) => getTokenWithInfoFromAddress(...a),
}));

import { AddressInputState } from '$components/Bridge/SharedBridgeComponents/AddressInput/state';
import { importDone, selectedNFTs } from '$components/Bridge/state';
import { TokenType } from '$libs/token';
import { account } from '$stores/account';
import { connectedSourceChain } from '$stores/network';

import ManualImport from './ManualImport.svelte';

const ADDRESS_A = '0x1111111111111111111111111111111111111111';
const ADDRESS_B = '0x2222222222222222222222222222222222222222';
const SRC_CHAIN = 1;

let target: HTMLElement;
let component: { $destroy: () => void; $$: { ctx: unknown[] } } | null = null;

const flush = async () => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  await tick();
};

const addressInput = () => target.querySelectorAll('input')[0] as HTMLInputElement;

const type = async (input: HTMLInputElement, value: string) => {
  input.value = value;
  input.dispatchEvent(new Event('input', { bubbles: true }));
  await tick();
};

/** The address field's validity styling reflects addressInputState */
const addressIsMarkedValid = () => addressInput().className.includes('success');

beforeEach(() => {
  detectContractType.mockReset();
  checkOwnership.mockReset();
  getTokenWithInfoFromAddress.mockReset();
  selectedNFTs.set(null);
  importDone.set(false);
  connectedSourceChain.set({ id: SRC_CHAIN } as never);
  account.set({ address: '0xaaaa', isConnected: true } as never);
  target = document.createElement('div');
  document.body.appendChild(target);
  component = new ManualImport({ target, props: {} }) as never;
});

afterEach(() => {
  component?.$destroy();
  component = null;
  target.remove();
});

describe('ManualImport contract address', () => {
  it('marks a detected NFT contract valid', async () => {
    detectContractType.mockResolvedValue(TokenType.ERC721);

    await type(addressInput(), ADDRESS_A);
    await flush();

    expect(addressIsMarkedValid()).toBe(true);
  });

  it('does not let an older lookup decide the state of a newer address', async () => {
    // A is an NFT contract, B is not. If A's late answer wins, a plain ERC20 address is
    // presented as a valid NFT contract and the id field opens for the wrong type.
    let resolveA!: (value: TokenType) => void;
    detectContractType
      .mockReturnValueOnce(new Promise<TokenType>((resolve) => (resolveA = resolve)))
      .mockResolvedValueOnce(TokenType.ERC20);

    await type(addressInput(), ADDRESS_A);
    await tick();

    // A newer address supersedes the pending lookup for A
    await type(addressInput(), ADDRESS_B);
    await flush();
    expect(addressIsMarkedValid()).toBe(false);

    // A resolves late, claiming a type that would make the field valid
    resolveA(TokenType.ERC721);
    await flush();

    expect(detectContractType).toHaveBeenNthCalledWith(1, ADDRESS_A, SRC_CHAIN);
    expect(detectContractType).toHaveBeenNthCalledWith(2, ADDRESS_B, SRC_CHAIN);
    // B's answer must stand: A describes an address no longer on screen
    expect(addressIsMarkedValid()).toBe(false);
    expect(get(importDone)).toBe(false);
  });

  it('discards a pending lookup when the field is cleared', async () => {
    let resolveA!: (value: TokenType) => void;
    detectContractType.mockReturnValue(new Promise<TokenType>((resolve) => (resolveA = resolve)));

    await type(addressInput(), ADDRESS_A);
    await tick();

    // Clearing dispatches no validation event at all
    await type(addressInput(), '');
    await flush();

    resolveA(TokenType.ERC721);
    await flush();

    // The abandoned lookup must not mark an empty field as a valid NFT contract
    expect(addressIsMarkedValid()).toBe(false);
    expect(get(importDone)).toBe(false);
  });

  it('does not mark a failed lookup valid using the previous address type', async () => {
    detectContractType.mockResolvedValueOnce(TokenType.ERC721).mockRejectedValueOnce(new Error('rpc down'));

    await type(addressInput(), ADDRESS_A);
    await flush();
    expect(addressIsMarkedValid()).toBe(true);

    await type(addressInput(), ADDRESS_B);
    await flush();

    expect(addressIsMarkedValid()).toBe(false);
    expect(get(importDone)).toBe(false);
  });

  it('does not report a non-NFT contract as valid', async () => {
    detectContractType.mockResolvedValue(TokenType.ERC20);

    await type(addressInput(), ADDRESS_A);
    await flush();

    expect(addressIsMarkedValid()).toBe(false);
    expect(AddressInputState.NOT_NFT).toBeDefined();
  });
});
