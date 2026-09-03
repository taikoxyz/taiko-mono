/**
 * ERC721 and ERC1155 now share one implementation. These pin what each standard still
 * decides for itself - how "approved" is read and how it is granted - and that the shared
 * approve flow around them behaves the same for both.
 */
import type { Address, WalletClient } from 'viem';
import { vi } from 'vitest';

import { NoApprovalRequiredError, NoCanonicalInfoFoundError, NotApprovedError, SendERC721Error } from '$libs/error';
import { ALICE, L1_CHAIN_ID, L2_CHAIN_ID } from '$mocks';

const readContract = vi.fn();
const simulateContract = vi.fn();
const writeContract = vi.fn();
const getPublicClient = vi.fn();
vi.mock('@wagmi/core', () => ({
  readContract: (...args: unknown[]) => readContract(...args),
  simulateContract: (...args: unknown[]) => simulateContract(...args),
  writeContract: (...args: unknown[]) => writeContract(...args),
  getPublicClient: (...args: unknown[]) => getPublicClient(...args),
}));
vi.mock('$libs/wagmi', () => ({ config: {} }));
vi.mock('$bridgeConfig');

const getCanonicalInfoForAddress = vi.fn();
vi.mock('$libs/token/getCanonicalInfoForToken', () => ({
  getCanonicalInfoForAddress: (...args: unknown[]) => getCanonicalInfoForAddress(...args),
}));

const estimateMessageGasLimit = vi.fn();
vi.mock('./estimateMessageGasLimit', () => ({
  estimateMessageGasLimitWithMinimum: (...args: unknown[]) => estimateMessageGasLimit(...args),
}));

const isBridgePaused = vi.fn();
vi.mock('$libs/util/checkForPausedContracts', () => ({
  isBridgePaused: (...args: unknown[]) => isBridgePaused(...args),
}));

import { ERC721Bridge } from './ERC721Bridge';
import { ERC1155Bridge } from './ERC1155Bridge';

const TOKEN = '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599' as Address;
const VAULT = '0x0000000000000000000000000000000000000456' as Address;
const OTHER = '0x0000000000000000000000000000000000000999' as Address;
const prover = {} as never;

const wallet = { account: { address: ALICE }, chain: { id: L1_CHAIN_ID } } as unknown as WalletClient;
const approveArgs = { tokenAddress: TOKEN, spenderAddress: VAULT, wallet, tokenIds: [BigInt(7)] };

const base = {
  to: ALICE as Address,
  srcChainId: L1_CHAIN_ID,
  destChainId: L2_CHAIN_ID,
  fee: BigInt(1000),
  tokenObject: { type: 'ERC721', symbol: 'NFT', decimals: 0, addresses: {} },
};

/** Stands in for the ERC1155 token contract handle */
const isApprovedForAll = vi.fn();
vi.mock('viem', async (importOriginal) => ({
  ...(await importOriginal<typeof import('viem')>()),
  getContract: () => ({ read: { isApprovedForAll: (...args: unknown[]) => isApprovedForAll(...args) } }),
}));

beforeEach(() => {
  vi.clearAllMocks();
  getPublicClient.mockReturnValue({});
  simulateContract.mockResolvedValue({ request: { simulated: true } });
  writeContract.mockResolvedValue('0xtx');
});

describe('ERC721Bridge approval', () => {
  const bridge = () => new ERC721Bridge(prover);
  const args = { tokenAddress: TOKEN, spenderAddress: VAULT, tokenId: BigInt(7), chainId: L1_CHAIN_ID };

  it('needs no approval when the vault already holds the per-token one', async () => {
    readContract.mockResolvedValueOnce(VAULT);

    expect(await bridge().requiresApproval(args)).toBe(false);
  });

  it('compares the approved address checksummed', async () => {
    readContract.mockResolvedValueOnce(VAULT.toLowerCase());

    expect(await bridge().requiresApproval(args)).toBe(false);
  });

  it('falls back to the operator approval', async () => {
    readContract.mockResolvedValueOnce(OTHER).mockResolvedValueOnce(true);

    expect(await bridge().requiresApproval({ ...args, owner: ALICE })).toBe(false);
  });

  it('needs approval when neither is granted', async () => {
    readContract.mockResolvedValueOnce(OTHER).mockResolvedValueOnce(false);

    expect(await bridge().requiresApproval({ ...args, owner: ALICE })).toBe(true);
  });

  it('reads against the chain it was given', async () => {
    // It used to read the connected wallet's chain and ignore this argument, which made the
    // answer describe whichever chain the wallet happened to be on
    readContract.mockResolvedValueOnce(OTHER).mockResolvedValueOnce(false);

    await bridge().requiresApproval({ ...args, owner: ALICE, chainId: 999 });

    expect(readContract).toHaveBeenNthCalledWith(1, {}, expect.objectContaining({ chainId: 999 }));
  });

  it('approves the single token, not the collection', async () => {
    readContract.mockResolvedValueOnce(OTHER).mockResolvedValueOnce(false);

    await bridge().approve(approveArgs);

    expect(simulateContract).toHaveBeenCalledWith(
      {},
      expect.objectContaining({ functionName: 'approve', args: [VAULT, BigInt(7)] }),
    );
    expect(writeContract).toHaveBeenCalledWith({}, { simulated: true });
  });
});

describe('ERC1155Bridge approval', () => {
  const bridge = () => new ERC1155Bridge(prover);
  const args = { tokenAddress: TOKEN, spenderAddress: VAULT, tokenId: BigInt(7), chainId: L1_CHAIN_ID, owner: ALICE };

  it('needs approval exactly when the operator approval is absent', async () => {
    isApprovedForAll.mockResolvedValueOnce(false);
    expect(await bridge().requiresApproval(args)).toBe(true);

    isApprovedForAll.mockResolvedValueOnce(true);
    expect(await bridge().requiresApproval(args)).toBe(false);
  });

  it('approves the whole collection, which is all ERC1155 offers', async () => {
    isApprovedForAll.mockResolvedValueOnce(false);

    await bridge().approve(approveArgs);

    expect(simulateContract).toHaveBeenCalledWith(
      {},
      expect.objectContaining({ functionName: 'setApprovalForAll', args: [VAULT, true] }),
    );
  });
});

describe('deciding whether the vault needs approval', () => {
  const args = (token: string) =>
    ({
      ...base,
      token,
      tokenVaultAddress: VAULT,
      tokenIds: [1],
      amounts: [0n],
      wallet,
    }) as never;

  beforeEach(() => {
    // A well-formed message, so the send reaches the canonical-address branch
    estimateMessageGasLimit.mockResolvedValue({ gasLimit: 1_000_000, minGasLimit: 100_000 });
    isBridgePaused.mockResolvedValue(false);
    getCanonicalInfoForAddress.mockResolvedValue({ address: TOKEN.toLowerCase() });
  });

  it('checks approval for a native token whose canonical address differs only in casing', async () => {
    // The canonical lookup and the args reach here from different places. Compared
    // strictly, a casing difference reads as "bridged" and skips the approval check
    // entirely - sending a transfer the vault has no permission to make
    readContract.mockResolvedValueOnce(OTHER).mockResolvedValueOnce(false);

    await expect(new ERC721Bridge(prover).bridge(args(TOKEN))).rejects.toThrow(NotApprovedError);
  });

  it('reports a failed approval read as a failure to send this token', async () => {
    // Not a bare Error from a lookup the caller never invoked: an RPC that dies while
    // asking about approval is a failure to send, and says so in the token's own error
    readContract.mockRejectedValue(new Error('rpc down'));

    await expect(new ERC721Bridge(prover).bridge(args(TOKEN))).rejects.toThrow(SendERC721Error);
  });

  it('keeps the two verdicts this phase exists to reach as themselves', async () => {
    getCanonicalInfoForAddress.mockResolvedValue(null);

    await expect(new ERC721Bridge(prover).bridge(args(TOKEN))).rejects.toThrow(NoCanonicalInfoFoundError);
  });

  it('skips the approval check for a genuinely bridged token', async () => {
    getCanonicalInfoForAddress.mockResolvedValue({ address: OTHER });

    // Straight through to the contract call: the vault mints a bridged token itself, so
    // there is no approval to read and none to demand
    await expect(new ERC721Bridge(prover).bridge(args(TOKEN))).resolves.toBe('0xtx');
    expect(readContract).not.toHaveBeenCalled();
  });

  it('simulates and writes as the wallet it was given, on the source chain', async () => {
    // Without these, wagmi signs with whatever account and chain the connector holds by
    // the time the write runs - an account switched during preparation sends from the new
    // one while the record names the old
    getCanonicalInfoForAddress.mockResolvedValue({ address: OTHER });

    await new ERC721Bridge(prover).bridge(args(TOKEN));

    expect(simulateContract).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ functionName: 'sendToken', account: wallet.account, chainId: L1_CHAIN_ID }),
    );
    expect(writeContract).toHaveBeenCalledWith(expect.anything(), { simulated: true });
  });
});

describe('the shared approve flow', () => {
  it('refuses an ERC721 approval that is already granted', async () => {
    readContract.mockResolvedValueOnce(VAULT);

    await expect(new ERC721Bridge(prover).approve(approveArgs)).rejects.toThrow(NoApprovalRequiredError);
    expect(simulateContract).not.toHaveBeenCalled();
  });

  it('refuses an ERC1155 approval that is already granted', async () => {
    isApprovedForAll.mockResolvedValueOnce(true);

    await expect(new ERC1155Bridge(prover).approve(approveArgs)).rejects.toThrow(NoApprovalRequiredError);
    expect(simulateContract).not.toHaveBeenCalled();
  });

  it.each([
    ['ERC721', () => new ERC721Bridge(prover)],
    ['ERC1155', () => new ERC1155Bridge(prover)],
  ])('%s reports a wallet that is not connected', async (_name, make) => {
    await expect(make().approve({ ...approveArgs, wallet: undefined as never })).rejects.toThrow(
      'Wallet is not connected',
    );
  });
});
