/**
 * The invariant checks are only worth having if the bridges actually run them. This walks
 * a message that breaks each contract rule through the real send path and asserts it is
 * refused before any contract call - the checks existed but were wired into nothing, so
 * every one of these reached the chain and came back as a bare revert selector.
 */
import { readContract } from '@wagmi/core';
import type { Address, WalletClient } from 'viem';
import { vi } from 'vitest';

import { BridgePausedError, InvalidMessageError } from '$libs/error';
import { ALICE, L1_CHAIN_ID, L2_CHAIN_ID } from '$mocks';

vi.mock('@wagmi/core');
vi.mock('$bridgeConfig');

const isBridgePaused = vi.fn();
vi.mock('$libs/util/checkForPausedContracts', () => ({
  isBridgePaused: (...args: unknown[]) => isBridgePaused(...args),
}));

const estimateMessageGasLimit = vi.fn();
vi.mock('./estimateMessageGasLimit', () => ({
  estimateMessageGasLimit: (...args: unknown[]) => estimateMessageGasLimit(...args),
}));

// ERC20Bridge.bridge reads the allowance before it prepares the transaction
vi.mock('$libs/util/getConnectedWallet', () => ({
  getConnectedWallet: () => Promise.resolve({ account: { address: ALICE }, chain: { id: 1 } }),
}));

// The contract handle is built before the check runs, and the check must fire first
const estimateGasSpy = vi.fn();
vi.mock('viem', async (importOriginal) => ({
  ...(await importOriginal<typeof import('viem')>()),
  getContract: () => ({
    address: '0x0000000000000000000000000000000000000005',
    estimateGas: { sendToken: estimateGasSpy, sendMessage: estimateGasSpy },
  }),
}));

import { destOwnerAddress, gasLimitZero } from '$components/Bridge/state';

import { ERC20Bridge } from './ERC20Bridge';
import { ERC721Bridge } from './ERC721Bridge';
import { ERC1155Bridge } from './ERC1155Bridge';
import { ETHBridge } from './ETHBridge';

const ZERO = '0x0000000000000000000000000000000000000000' as Address;
const TOKEN = '0x0000000000000000000000000000000000000123' as Address;
const VAULT = '0x0000000000000000000000000000000000000456' as Address;

const wallet = { account: { address: ALICE }, chain: { id: L1_CHAIN_ID } } as unknown as WalletClient;
const prover = {} as never;

const base = {
  to: ALICE as Address,
  wallet,
  srcChainId: L1_CHAIN_ID,
  destChainId: L2_CHAIN_ID,
  fee: BigInt(1000),
  tokenObject: { type: 'ERC20', symbol: 'TKN', decimals: 18, addresses: {} } as never,
};

beforeEach(() => {
  vi.clearAllMocks();
  estimateMessageGasLimit.mockResolvedValue(1_000_000);
  isBridgePaused.mockResolvedValue(false);
  gasLimitZero.set(false);
  destOwnerAddress.set(null);
});

describe('bridges refuse messages the contracts would reject', () => {
  describe('ERC20', () => {
    const bridge = () => new ERC20Bridge(prover);
    const args = (overrides = {}) =>
      ({ ...base, amount: BigInt(10), token: TOKEN, tokenVaultAddress: VAULT, ...overrides }) as never;

    it('refuses a zero amount', async () => {
      // ERC20Vault.sendToken reverts with VAULT_INVALID_AMOUNT
      await expect(bridge().estimateGas(args({ amount: BigInt(0) }))).rejects.toThrow(InvalidMessageError);
      expect(estimateGasSpy).not.toHaveBeenCalled();
    });

    it('refuses a zero token address', async () => {
      await expect(bridge().estimateGas(args({ token: ZERO }))).rejects.toThrow(InvalidMessageError);
      expect(estimateGasSpy).not.toHaveBeenCalled();
    });

    it('refuses a zero recipient', async () => {
      await expect(bridge().estimateGas(args({ to: ZERO }))).rejects.toThrow(InvalidMessageError);
      expect(estimateGasSpy).not.toHaveBeenCalled();
    });

    it('refuses the same source and destination chain', async () => {
      await expect(bridge().estimateGas(args({ destChainId: L1_CHAIN_ID }))).rejects.toThrow(InvalidMessageError);
      expect(estimateGasSpy).not.toHaveBeenCalled();
    });

    it('lets a well-formed transfer through to the contract', async () => {
      await bridge().estimateGas(args());
      expect(estimateGasSpy).toHaveBeenCalledOnce();
    });

    it('lets a zero gas limit through once the fee is zeroed with it', async () => {
      // This is the pairing that reverted with B_INVALID_FEE (0xc9f51787): feeForGasLimit
      // zeroes the fee, and the invariant check confirms the pair is consistent
      gasLimitZero.set(true);
      await bridge().estimateGas(args());
      expect(estimateGasSpy).toHaveBeenCalledOnce();
    });
  });

  describe('ETH', () => {
    const args = (overrides = {}) => ({ ...base, amount: BigInt(10), bridgeAddress: VAULT, ...overrides }) as never;

    it('refuses a zero recipient', async () => {
      await expect(new ETHBridge(prover).estimateGas(args({ to: ZERO }))).rejects.toThrow(InvalidMessageError);
      expect(estimateGasSpy).not.toHaveBeenCalled();
    });

    it('refuses a zero destination owner', async () => {
      destOwnerAddress.set(ZERO);
      await expect(new ETHBridge(prover).estimateGas(args())).rejects.toThrow(InvalidMessageError);
      expect(estimateGasSpy).not.toHaveBeenCalled();
    });

    it('lets a well-formed transfer through to the contract', async () => {
      await new ETHBridge(prover).estimateGas(args());
      expect(estimateGasSpy).toHaveBeenCalledOnce();
    });
  });

  describe('ERC721', () => {
    const args = (overrides = {}) =>
      ({
        ...base,
        token: TOKEN,
        tokenVaultAddress: VAULT,
        tokenIds: [1],
        amounts: [0],
        ...overrides,
      }) as never;

    it('refuses a non-zero amount', async () => {
      // ERC721Vault requires every amount to be zero
      await expect(new ERC721Bridge(prover).estimateGas(args({ amounts: [1] }))).rejects.toThrow(InvalidMessageError);
      expect(estimateGasSpy).not.toHaveBeenCalled();
    });

    it('refuses mismatched id and amount arrays', async () => {
      await expect(new ERC721Bridge(prover).estimateGas(args({ tokenIds: [1, 2], amounts: [0] }))).rejects.toThrow(
        InvalidMessageError,
      );
      expect(estimateGasSpy).not.toHaveBeenCalled();
    });

    it('lets a well-formed transfer through to the contract', async () => {
      await new ERC721Bridge(prover).estimateGas(args());
      expect(estimateGasSpy).toHaveBeenCalledOnce();
    });
  });

  describe('ERC1155', () => {
    const args = (overrides = {}) =>
      ({
        ...base,
        token: TOKEN,
        tokenVaultAddress: VAULT,
        tokenIds: [1],
        amounts: [5],
        ...overrides,
      }) as never;

    it('refuses a zero quantity', async () => {
      // ERC1155Vault requires every amount to be non-zero
      await expect(new ERC1155Bridge(prover).estimateGas(args({ amounts: [0] }))).rejects.toThrow(InvalidMessageError);
      expect(estimateGasSpy).not.toHaveBeenCalled();
    });

    it('refuses mismatched id and amount arrays', async () => {
      await expect(new ERC1155Bridge(prover).estimateGas(args({ tokenIds: [1, 2], amounts: [5] }))).rejects.toThrow(
        InvalidMessageError,
      );
      expect(estimateGasSpy).not.toHaveBeenCalled();
    });

    it('lets a well-formed transfer through to the contract', async () => {
      await new ERC1155Bridge(prover).estimateGas(args());
      expect(estimateGasSpy).toHaveBeenCalledOnce();
    });
  });
});

/**
 * A paused bridge reverts sendMessage/sendToken on chain, so building the transaction at
 * all is wasted gas and an unexplained revert. The check used to sit on the individual
 * methods, which left ERC1155 without one anywhere and ERC721/ERC20 without one on the
 * send itself; it now sits on the `_prepareTransaction` every token type shares.
 */
describe('bridges refuse to build a message while the source bridge is paused', () => {
  const erc20Args = { ...base, amount: BigInt(10), token: TOKEN, tokenVaultAddress: VAULT } as never;
  const ethArgs = { ...base, amount: BigInt(10), bridgeAddress: VAULT } as never;
  const erc721Args = { ...base, token: TOKEN, tokenVaultAddress: VAULT, tokenIds: [1], amounts: [0] } as never;
  const erc1155Args = { ...base, token: TOKEN, tokenVaultAddress: VAULT, tokenIds: [1], amounts: [5] } as never;

  const cases = [
    ['ETH', () => new ETHBridge(prover), ethArgs],
    ['ERC20', () => new ERC20Bridge(prover), erc20Args],
    ['ERC721', () => new ERC721Bridge(prover), erc721Args],
    ['ERC1155', () => new ERC1155Bridge(prover), erc1155Args],
  ] as const;

  it.each(cases)('%s refuses to estimate', async (_name, make, args) => {
    isBridgePaused.mockResolvedValue(true);

    await expect(make().estimateGas(args)).rejects.toThrow(BridgePausedError);
    expect(estimateGasSpy).not.toHaveBeenCalled();
  });

  it.each(cases)('%s refuses to send', async (_name, make, args) => {
    isBridgePaused.mockResolvedValue(true);
    // ERC20 reads the allowance first; a satisfied one lets it reach the shared guard
    vi.mocked(readContract).mockResolvedValue(BigInt(1e30));

    await expect(make().bridge(args)).rejects.toThrow(BridgePausedError);
  });

  it.each(cases)('%s asks about its own source chain, not every configured one', async (_name, make, args) => {
    await make().estimateGas(args);

    expect(isBridgePaused).toHaveBeenCalledWith(L1_CHAIN_ID);
  });
});
