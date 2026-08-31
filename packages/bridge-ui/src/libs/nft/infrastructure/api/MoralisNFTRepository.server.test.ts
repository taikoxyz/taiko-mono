import type { Address } from 'viem';

import type { NFTApiData } from '$nftAPI/infrastructure/types/moralis';

vi.mock('moralis', () => {
  return {
    default: {
      start: vi.fn().mockResolvedValue(undefined),
      EvmApi: {
        nft: {
          getWalletNFTs: vi.fn(),
        },
      },
    },
  };
});

vi.mock('$nftAPI/infrastructure/mappers/nft/MoralisNFTMapper', () => ({
  mapToNFTFromMoralis: vi.fn((nft: NFTApiData, chainId: number) => ({
    tokenId: Number((nft as unknown as { tokenId: number }).tokenId),
    chainId,
  })),
}));

import Moralis from 'moralis';

import repository from './MoralisNFTRepository.server';

const ADDRESS_A = '0x1111111111111111111111111111111111111111' as Address;
const ADDRESS_B = '0x2222222222222222222222222222222222222222' as Address;
const CHAIN_ID = 1;

const getWalletNFTs = vi.mocked(Moralis.EvmApi.nft.getWalletNFTs);

const moralisPage = (tokenIds: number[], cursor: string | null) =>
  ({
    pagination: { cursor },
    result: tokenIds.map((tokenId) => ({ tokenId })),
  }) as unknown as Awaited<ReturnType<typeof Moralis.EvmApi.nft.getWalletNFTs>>;

describe('MoralisNFTRepository.server', () => {
  beforeEach(() => {
    getWalletNFTs.mockReset();
  });

  it('does not serve one user the NFTs cached for another user', async () => {
    // Given: user A has fetched their complete NFT list (no cursor => all fetched)
    getWalletNFTs.mockResolvedValueOnce(moralisPage([1, 2], null));
    const nftsA = await repository.findByAddress({ address: ADDRESS_A, chainId: CHAIN_ID, refresh: true });
    expect(nftsA).toHaveLength(2);

    // When: user B fetches on the same chain
    getWalletNFTs.mockResolvedValueOnce(moralisPage([3], null));
    const nftsB = await repository.findByAddress({ address: ADDRESS_B, chainId: CHAIN_ID, refresh: true });

    // Then: B gets their own list, fetched from the start (no cursor from A's pagination)
    expect(nftsB).toEqual([{ tokenId: 3, chainId: CHAIN_ID }]);
    expect(getWalletNFTs).toHaveBeenLastCalledWith(expect.objectContaining({ address: ADDRESS_B, cursor: '' }));

    // And: A's cached list is untouched
    const cachedA = await repository.findByAddress({ address: ADDRESS_A, chainId: CHAIN_ID, refresh: false });
    expect(cachedA).toEqual([
      { tokenId: 1, chainId: CHAIN_ID },
      { tokenId: 2, chainId: CHAIN_ID },
    ]);
  });

  it('continues pagination per user with that user’s own cursor', async () => {
    // Given: user A's first page leaves a cursor
    getWalletNFTs.mockResolvedValueOnce(moralisPage([1], 'cursor-a-page2'));
    await repository.findByAddress({ address: ADDRESS_A, chainId: CHAIN_ID, refresh: true });

    // And: user B fetches in between, leaving their own cursor
    getWalletNFTs.mockResolvedValueOnce(moralisPage([9], 'cursor-b-page2'));
    await repository.findByAddress({ address: ADDRESS_B, chainId: CHAIN_ID, refresh: true });

    // When: user A loads their next page
    getWalletNFTs.mockResolvedValueOnce(moralisPage([2], null));
    const nftsA = await repository.findByAddress({ address: ADDRESS_A, chainId: CHAIN_ID, refresh: false });

    // Then: the request used A's cursor, not B's, and A's list accumulated
    expect(getWalletNFTs).toHaveBeenLastCalledWith(
      expect.objectContaining({ address: ADDRESS_A, cursor: 'cursor-a-page2' }),
    );
    expect(nftsA).toEqual([
      { tokenId: 1, chainId: CHAIN_ID },
      { tokenId: 2, chainId: CHAIN_ID },
    ]);
  });

  it('keeps caches separate per chain for the same address', async () => {
    getWalletNFTs.mockResolvedValueOnce(moralisPage([1], null));
    await repository.findByAddress({ address: ADDRESS_A, chainId: 1, refresh: true });

    getWalletNFTs.mockResolvedValueOnce(moralisPage([2], null));
    const otherChain = await repository.findByAddress({ address: ADDRESS_A, chainId: 2, refresh: true });

    expect(otherChain).toEqual([{ tokenId: 2, chainId: 2 }]);
    expect(getWalletNFTs).toHaveBeenLastCalledWith(expect.objectContaining({ chain: 2, cursor: '' }));
  });

  it('refresh resets only the requesting user’s pagination state', async () => {
    getWalletNFTs.mockResolvedValueOnce(moralisPage([1], null));
    await repository.findByAddress({ address: ADDRESS_A, chainId: CHAIN_ID, refresh: true });

    getWalletNFTs.mockResolvedValueOnce(moralisPage([9], 'cursor-b-page2'));
    await repository.findByAddress({ address: ADDRESS_B, chainId: CHAIN_ID, refresh: true });

    // When: A refreshes
    getWalletNFTs.mockResolvedValueOnce(moralisPage([1, 5], null));
    const refreshedA = await repository.findByAddress({ address: ADDRESS_A, chainId: CHAIN_ID, refresh: true });
    expect(refreshedA).toEqual([
      { tokenId: 1, chainId: CHAIN_ID },
      { tokenId: 5, chainId: CHAIN_ID },
    ]);

    // Then: B's pagination cursor survives
    getWalletNFTs.mockResolvedValueOnce(moralisPage([10], null));
    await repository.findByAddress({ address: ADDRESS_B, chainId: CHAIN_ID, refresh: false });
    expect(getWalletNFTs).toHaveBeenLastCalledWith(
      expect.objectContaining({ address: ADDRESS_B, cursor: 'cursor-b-page2' }),
    );
  });

  it('serializes concurrent requests for the same wallet so pages are not fetched twice', async () => {
    getWalletNFTs.mockResolvedValueOnce(moralisPage([1], 'cursor-page2')).mockResolvedValueOnce(moralisPage([2], null));

    // Fire both before either resolves: without serialization they would share the
    // same cursor and duplicate page 1
    const [first, second] = await Promise.all([
      repository.findByAddress({ address: ADDRESS_A, chainId: CHAIN_ID, refresh: true }),
      repository.findByAddress({ address: ADDRESS_A, chainId: CHAIN_ID, refresh: false }),
    ]);

    expect(first).toEqual([{ tokenId: 1, chainId: CHAIN_ID }]);
    expect(second).toEqual([
      { tokenId: 1, chainId: CHAIN_ID },
      { tokenId: 2, chainId: CHAIN_ID },
    ]);
    expect(getWalletNFTs).toHaveBeenNthCalledWith(1, expect.objectContaining({ cursor: '' }));
    expect(getWalletNFTs).toHaveBeenNthCalledWith(2, expect.objectContaining({ cursor: 'cursor-page2' }));
  });

  it('keeps already-fetched pages when a later page fails', async () => {
    getWalletNFTs.mockResolvedValueOnce(moralisPage([1], 'cursor-page2'));
    await repository.findByAddress({ address: ADDRESS_A, chainId: CHAIN_ID, refresh: true });

    getWalletNFTs.mockRejectedValueOnce(new Error('rate limited'));
    const afterFailure = await repository.findByAddress({ address: ADDRESS_A, chainId: CHAIN_ID, refresh: false });

    // The first page survives the failed second page and the cursor is retried next call
    expect(afterFailure).toEqual([{ tokenId: 1, chainId: CHAIN_ID }]);
    getWalletNFTs.mockResolvedValueOnce(moralisPage([2], null));
    const retried = await repository.findByAddress({ address: ADDRESS_A, chainId: CHAIN_ID, refresh: false });
    expect(retried).toEqual([
      { tokenId: 1, chainId: CHAIN_ID },
      { tokenId: 2, chainId: CHAIN_ID },
    ]);
    expect(getWalletNFTs).toHaveBeenLastCalledWith(expect.objectContaining({ cursor: 'cursor-page2' }));
  });

  it('returns an empty array when the Moralis request fails, without caching the failure as complete', async () => {
    getWalletNFTs.mockRejectedValueOnce(new Error('rate limited'));
    const failed = await repository.findByAddress({ address: ADDRESS_A, chainId: CHAIN_ID, refresh: true });
    expect(failed).toEqual([]);

    // A retry goes back to the API instead of returning the empty failure result
    getWalletNFTs.mockResolvedValueOnce(moralisPage([7], null));
    const retried = await repository.findByAddress({ address: ADDRESS_A, chainId: CHAIN_ID, refresh: false });
    expect(retried).toEqual([{ tokenId: 7, chainId: CHAIN_ID }]);
  });
});
