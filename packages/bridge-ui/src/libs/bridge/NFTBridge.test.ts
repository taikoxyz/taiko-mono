/**
 * ERC721 and ERC1155 now share one implementation. These pin what each standard still
 * decides for itself - how "approved" is read and how it is granted - and that the shared
 * approve flow around them behaves the same for both.
 */
import type { Address, WalletClient } from 'viem';
import { vi } from 'vitest';

import { NoApprovalRequiredError } from '$libs/error';
import { ALICE, L1_CHAIN_ID } from '$mocks';

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

import { ERC721Bridge } from './ERC721Bridge';
import { ERC1155Bridge } from './ERC1155Bridge';

const TOKEN = '0x0000000000000000000000000000000000000123' as Address;
const VAULT = '0x0000000000000000000000000000000000000456' as Address;
const OTHER = '0x0000000000000000000000000000000000000999' as Address;
const prover = {} as never;

const wallet = { account: { address: ALICE }, chain: { id: L1_CHAIN_ID } } as unknown as WalletClient;
const approveArgs = { tokenAddress: TOKEN, spenderAddress: VAULT, wallet, tokenIds: [BigInt(7)] };

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
