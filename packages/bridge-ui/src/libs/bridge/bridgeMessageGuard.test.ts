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
  estimateMessageGasLimitWithMinimum: (...args: unknown[]) => estimateMessageGasLimit(...args),
}));

// ERC20Bridge.bridge reads the allowance before it prepares the transaction
vi.mock('$libs/util/getConnectedWallet', () => ({
  getConnectedWallet: () => Promise.resolve({ account: { address: ALICE }, chain: { id: 1 } }),
}));

// The contract handle is built before the check runs, and the check must fire first.
// The stub echoes what it was built with: after the four send paths were folded onto one
// preamble, nothing else pinned which vault each token type talks to.
const estimateGasSpy = vi.fn();
const getContractSpy = vi.fn();
vi.mock('viem', async (importOriginal) => ({
  ...(await importOriginal<typeof import('viem')>()),
  getContract: (options: { address: string; abi: unknown }) => {
    getContractSpy(options);
    return {
      address: options.address,
      abi: options.abi,
      estimateGas: { sendToken: estimateGasSpy, sendMessage: estimateGasSpy },
    };
  },
}));

import { bridgeAbi, erc20VaultAbi, erc721VaultAbi, erc1155VaultAbi } from '$abi';
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
  estimateMessageGasLimit.mockResolvedValue({ gasLimit: 1_000_000, minGasLimit: 100_000 });
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
        amounts: [0n],
        ...overrides,
      }) as never;

    it('refuses a non-zero amount', async () => {
      // ERC721Vault requires every amount to be zero
      await expect(new ERC721Bridge(prover).estimateGas(args({ amounts: [1n] }))).rejects.toThrow(InvalidMessageError);
      expect(estimateGasSpy).not.toHaveBeenCalled();
    });

    it('refuses mismatched id and amount arrays', async () => {
      await expect(new ERC721Bridge(prover).estimateGas(args({ tokenIds: [1, 2], amounts: [0n] }))).rejects.toThrow(
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
        amounts: [5n],
        ...overrides,
      }) as never;

    it('refuses a zero quantity', async () => {
      // ERC1155Vault requires every amount to be non-zero
      await expect(new ERC1155Bridge(prover).estimateGas(args({ amounts: [0n] }))).rejects.toThrow(InvalidMessageError);
      expect(estimateGasSpy).not.toHaveBeenCalled();
    });

    it('refuses mismatched id and amount arrays', async () => {
      await expect(new ERC1155Bridge(prover).estimateGas(args({ tokenIds: [1, 2], amounts: [5n] }))).rejects.toThrow(
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
  const erc721Args = { ...base, token: TOKEN, tokenVaultAddress: VAULT, tokenIds: [1], amounts: [0n] } as never;
  const erc1155Args = { ...base, token: TOKEN, tokenVaultAddress: VAULT, tokenIds: [1], amounts: [5n] } as never;

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

/**
 * ETH, ERC20, ERC721 and ERC1155 reach their contract call through one shared preamble.
 * These pin the parts of a message that preamble decides, for every token type at once -
 * the pause check, the zero-gas-limit fee rule and the destination-owner default were each
 * fixed in one bridge at a time before they lived in a single place.
 */
describe('every token type builds the shared message fields the same way', () => {
  const erc20Args = { ...base, amount: BigInt(10), token: TOKEN, tokenVaultAddress: VAULT } as never;
  const ethArgs = { ...base, amount: BigInt(10), bridgeAddress: VAULT } as never;
  const erc721Args = { ...base, token: TOKEN, tokenVaultAddress: VAULT, tokenIds: [1], amounts: [0n] } as never;
  const erc1155Args = { ...base, token: TOKEN, tokenVaultAddress: VAULT, tokenIds: [1], amounts: [5n] } as never;

  const cases = [
    ['ETH', () => new ETHBridge(prover), ethArgs],
    ['ERC20', () => new ERC20Bridge(prover), erc20Args],
    ['ERC721', () => new ERC721Bridge(prover), erc721Args],
    ['ERC1155', () => new ERC1155Bridge(prover), erc1155Args],
  ] as const;

  /** The message or transfer op the bridge handed the contract */
  const sentMessage = () => estimateGasSpy.mock.calls[0][0][0];

  it.each(cases)('%s zeroes the fee alongside a zero gas limit', async (_name, make, args) => {
    // Paired: the bridge reverts with B_INVALID_FEE on a fee attached to a zero gas limit
    gasLimitZero.set(true);

    await make().estimateGas(args);

    expect(sentMessage().gasLimit).toBe(0);
    expect(sentMessage().fee).toBe(BigInt(0));
  });

  it.each(cases)('%s keeps the processing fee when the gas limit is not zero', async (_name, make, args) => {
    await make().estimateGas(args);

    expect(sentMessage().gasLimit).toBe(1_000_000);
    expect(sentMessage().fee).toBe(BigInt(1000));
  });

  it.each(cases)('%s sends to the recipient when no destination owner is set', async (_name, make, args) => {
    await make().estimateGas(args);

    expect(sentMessage().destOwner).toBe(ALICE);
  });

  it.each(cases)('%s honours an explicit destination owner', async (_name, make, args) => {
    const BOB = '0x0000000000000000000000000000000000000b0b';
    destOwnerAddress.set(BOB);

    await make().estimateGas(args);

    expect(sentMessage().destOwner).toBe(BOB);
  });

  it.each(cases)('%s refuses a gas limit the destination bridge would reject', async (_name, make, args) => {
    // Bridge.sendMessage subtracts the minimum and rejects a remainder of zero. The rule
    // existed but no caller supplied the minimum, so it could never fire
    estimateMessageGasLimit.mockResolvedValue({ gasLimit: 100_000, minGasLimit: 100_000 });

    await expect(make().estimateGas(args)).rejects.toThrow(InvalidMessageError);
    expect(estimateGasSpy).not.toHaveBeenCalled();
  });

  it.each(cases)('%s accepts a gas limit above the minimum', async (_name, make, args) => {
    estimateMessageGasLimit.mockResolvedValue({ gasLimit: 100_001, minGasLimit: 100_000 });

    await make().estimateGas(args);

    expect(estimateGasSpy).toHaveBeenCalledOnce();
  });

  it.each(cases)('%s skips the minimum rule when the gas limit is zero', async (_name, make, args) => {
    // No estimate runs, so no minimum is known - and a zero gas limit is governed by the
    // fee rule instead, which the case above pins
    gasLimitZero.set(true);

    await make().estimateGas(args);

    expect(estimateGasSpy).toHaveBeenCalledOnce();
  });

  it.each(cases)('%s reports a wallet that is not connected', async (_name, make, args) => {
    await expect(make().estimateGas({ ...(args as object), wallet: undefined } as never)).rejects.toThrow(
      'Wallet is not connected',
    );
  });
});

describe('each send path builds its transaction against its own contract', () => {
  const ERC20_VAULT = '0x00000000000000000000000000000000000000e2' as Address;
  const ERC721_VAULT = '0x0000000000000000000000000000000000000721' as Address;
  const ERC1155_VAULT = '0x0000000000000000000000000000000000001155' as Address;
  const BRIDGE = '0x00000000000000000000000000000000000000b1' as Address;

  it('ERC20 -> ERC20Vault with the ERC20 vault ABI', async () => {
    await new ERC20Bridge(prover).estimateGas({
      ...base,
      amount: BigInt(10),
      token: TOKEN,
      tokenVaultAddress: ERC20_VAULT,
    } as never);
    expect(getContractSpy).toHaveBeenCalledWith(expect.objectContaining({ address: ERC20_VAULT, abi: erc20VaultAbi }));
  });

  it('ETH -> Bridge with the bridge ABI', async () => {
    await new ETHBridge(prover).estimateGas({ ...base, amount: BigInt(10), bridgeAddress: BRIDGE } as never);
    expect(getContractSpy).toHaveBeenCalledWith(expect.objectContaining({ address: BRIDGE, abi: bridgeAbi }));
  });

  it('ERC721 -> ERC721Vault with the ERC721 vault ABI', async () => {
    await new ERC721Bridge(prover).estimateGas({
      ...base,
      token: TOKEN,
      tokenVaultAddress: ERC721_VAULT,
      tokenIds: [1],
      amounts: [0n],
    } as never);
    expect(getContractSpy).toHaveBeenCalledWith(
      expect.objectContaining({ address: ERC721_VAULT, abi: erc721VaultAbi }),
    );
    expect(getContractSpy).not.toHaveBeenCalledWith(expect.objectContaining({ abi: erc1155VaultAbi }));
  });

  it('ERC1155 -> ERC1155Vault with the ERC1155 vault ABI', async () => {
    await new ERC1155Bridge(prover).estimateGas({
      ...base,
      token: TOKEN,
      tokenVaultAddress: ERC1155_VAULT,
      tokenIds: [1],
      amounts: [1n],
    } as never);
    expect(getContractSpy).toHaveBeenCalledWith(
      expect.objectContaining({ address: ERC1155_VAULT, abi: erc1155VaultAbi }),
    );
    expect(getContractSpy).not.toHaveBeenCalledWith(expect.objectContaining({ abi: erc721VaultAbi }));
  });
});
