/**
 * The NFT branch answers one question for both standards. What it must never do is leave
 * the previous token's answer standing: Actions.svelte gates the Bridge button on
 * `allApproved`, so a stale `true` offers a bridge for a token nothing was read for.
 */
import { get } from 'svelte/store';

vi.mock('$bridgeConfig');
vi.mock('@wagmi/core');

const requiresApproval = vi.fn();
const requireAllowance = vi.fn();
vi.mock('$libs/bridge', async (importOriginal) => ({
  ...(await importOriginal<typeof import('$libs/bridge')>()),
  bridges: {
    ERC20: { requireAllowance: (...args: unknown[]) => requireAllowance(...args), getAllowance: vi.fn() },
    ERC721: { requiresApproval: (...args: unknown[]) => requiresApproval(...args) },
    ERC1155: { requiresApproval: (...args: unknown[]) => requiresApproval(...args) },
  },
}));

const checkOwnershipOfNFT = vi.fn();
vi.mock('./checkOwnership', () => ({
  checkOwnershipOfNFT: (...args: unknown[]) => checkOwnershipOfNFT(...args),
}));

vi.mock('$libs/util/getConnectedWallet', () => ({
  getConnectedWallet: () => Promise.resolve({ account: { address: '0xaaaa' }, chain: { id: 1 } }),
}));

vi.mock('$libs/bridge/getContractAddressByType', () => ({
  getContractAddressByType: () => '0x0000000000000000000000000000000000000456',
}));

import { allApproved, destNetwork, insufficientAllowance, selectedToken } from '$components/Bridge/state';
import { account, connectedSourceChain } from '$stores';

import { ApprovalStatus, getTokenApprovalStatus } from './getTokenApprovalStatus';
import { type NFT, type Token, TokenType } from './types';

const nft: NFT = {
  type: TokenType.ERC721,
  symbol: 'NFT',
  name: 'NFT',
  tokenId: 1,
  addresses: { 1: '0x0000000000000000000000000000000000000abc' },
} as unknown as NFT;

beforeEach(() => {
  vi.clearAllMocks();
  account.set({ address: '0xaaaa', isConnected: true } as never);
  connectedSourceChain.set({ id: 1 } as never);
  destNetwork.set({ id: 2 } as never);
  checkOwnershipOfNFT.mockResolvedValue([{ isOwner: true }]);
  // The function reads the token address off the selected-token store, not its argument
  selectedToken.set(nft);
  // A previously selected token left this standing
  allApproved.set(true);
});

describe('getTokenApprovalStatus for NFTs', () => {
  it('reports no approval required when the vault already has it', async () => {
    requiresApproval.mockResolvedValue(false);

    expect(await getTokenApprovalStatus(nft)).toBe(ApprovalStatus.NO_APPROVAL_REQUIRED);
    expect(get(allApproved)).toBe(true);
  });

  it('reports approval required and clears the flag', async () => {
    requiresApproval.mockResolvedValue(true);

    expect(await getTokenApprovalStatus(nft)).toBe(ApprovalStatus.APPROVAL_REQUIRED);
    expect(get(allApproved)).toBe(false);
  });

  it('clears the flag when the approval cannot be read at all', async () => {
    // The ERC20 branch already did this. Left set, the previous token's `true` keeps the
    // Bridge button enabled for a token whose approval state is unknown
    requiresApproval.mockRejectedValue(new Error('rpc down'));

    expect(await getTokenApprovalStatus(nft)).toBe(ApprovalStatus.APPROVAL_REQUIRED);
    expect(get(allApproved)).toBe(false);
  });

  it('clears the flag when the user does not own the token', async () => {
    checkOwnershipOfNFT.mockResolvedValue([{ isOwner: false }]);

    expect(await getTokenApprovalStatus(nft)).toBe(ApprovalStatus.APPROVAL_REQUIRED);
    expect(get(allApproved)).toBe(false);
    expect(requiresApproval).not.toHaveBeenCalled();
  });

  it('asks the ERC1155 bridge the same question', async () => {
    requiresApproval.mockResolvedValue(true);

    expect(await getTokenApprovalStatus({ ...nft, type: TokenType.ERC1155 } as NFT)).toBe(
      ApprovalStatus.APPROVAL_REQUIRED,
    );
    expect(requiresApproval).toHaveBeenCalledOnce();
  });

  it('clears a stale approval when the NFT ownership read fails', async () => {
    // The not-owner branch already clears it for the same reason: a previously selected
    // token's allApproved=true must not survive, or Bridge stays enabled for an NFT whose
    // approval state could not be read at all
    allApproved.set(true);
    checkOwnershipOfNFT.mockRejectedValue(new Error('rpc down'));

    await expect(getTokenApprovalStatus(nft)).rejects.toThrow('rpc down');

    expect(get(allApproved)).toBe(false);
  });
});

describe('getTokenApprovalStatus answers for the token it was given', () => {
  const otherNft: NFT = {
    ...nft,
    tokenId: 2,
    addresses: { 1: '0x0000000000000000000000000000000000000def' },
  } as unknown as NFT;

  it('reads the allowance of the token it was given, not of the selected one', async () => {
    // The read is polled for seconds after an approval, and the user can switch tokens in
    // that window. The ERC20 branch took its token address off the store, so it answered
    // the new token's question with the old token's name on it. (The NFT branch always read
    // its argument, which is why this is pinned on ERC20.)
    const erc20 = {
      type: TokenType.ERC20,
      symbol: 'TKN',
      name: 'Token',
      decimals: 18,
      addresses: { 1: '0x0000000000000000000000000000000000000aaa' },
    } as unknown as Token;
    const otherErc20 = {
      ...erc20,
      symbol: 'OTHER',
      addresses: { 1: '0x0000000000000000000000000000000000000bbb' },
    } as unknown as Token;
    selectedToken.set(otherErc20);
    requireAllowance.mockResolvedValue(true);

    await getTokenApprovalStatus(erc20);

    expect(requireAllowance).toHaveBeenCalledWith(expect.objectContaining({ tokenAddress: erc20.addresses[1] }));
  });

  it('does not publish a late answer for a token that is no longer selected', async () => {
    // A store write describes "the selected token"; a stale answer landing in it hands the
    // new token an approval nothing read for it
    selectedToken.set(otherNft);
    allApproved.set(false);
    requiresApproval.mockResolvedValue(false); // the previous token happens to be approved

    expect(await getTokenApprovalStatus(nft)).toBe(ApprovalStatus.NO_APPROVAL_REQUIRED);

    expect(get(allApproved)).toBe(false);
  });

  it('still publishes for the same token behind a fresh object', async () => {
    // Token lists are rebuilt on every refresh, so identity is by deployment, not by reference
    selectedToken.set({ ...nft });
    allApproved.set(false);
    requiresApproval.mockResolvedValue(false);

    await getTokenApprovalStatus(nft);

    expect(get(allApproved)).toBe(true);
  });

  it("keeps a late ERC20 allowance answer out of the current token's stores", async () => {
    const erc20 = {
      type: TokenType.ERC20,
      symbol: 'TKN',
      name: 'Token',
      decimals: 18,
      addresses: { 1: '0x0000000000000000000000000000000000000aaa' },
    } as unknown as Token;
    const otherErc20 = {
      ...erc20,
      symbol: 'OTHER',
      addresses: { 1: '0x0000000000000000000000000000000000000bbb' },
    } as unknown as Token;
    selectedToken.set(otherErc20);
    allApproved.set(false);
    insufficientAllowance.set(true);
    requireAllowance.mockResolvedValue(false); // the previous token has allowance

    expect(await getTokenApprovalStatus(erc20)).toBe(ApprovalStatus.NO_APPROVAL_REQUIRED);

    expect(get(allApproved)).toBe(false);
    expect(get(insufficientAllowance)).toBe(true);
  });
});
