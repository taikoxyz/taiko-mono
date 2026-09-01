/**
 * The NFT branch answers one question for both standards. What it must never do is leave
 * the previous token's answer standing: Actions.svelte gates the Bridge button on
 * `allApproved`, so a stale `true` offers a bridge for a token nothing was read for.
 */
import { get } from 'svelte/store';

vi.mock('$bridgeConfig');
vi.mock('@wagmi/core');

const requiresApproval = vi.fn();
vi.mock('$libs/bridge', async (importOriginal) => ({
  ...(await importOriginal<typeof import('$libs/bridge')>()),
  bridges: {
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

import { allApproved, destNetwork, selectedToken } from '$components/Bridge/state';
import { account, connectedSourceChain } from '$stores';

import { ApprovalStatus, getTokenApprovalStatus } from './getTokenApprovalStatus';
import { type NFT, TokenType } from './types';

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
});
