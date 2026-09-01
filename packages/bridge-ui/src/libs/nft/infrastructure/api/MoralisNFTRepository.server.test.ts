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

import { mapToNFTFromMoralis } from '$nftAPI/infrastructure/mappers/nft/MoralisNFTMapper';

import repository, { MAX_CACHED_WALLETS, PAGE_REQUEST_TIMEOUT_MS } from './MoralisNFTRepository.server';

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

  it('reports a failed page instead of returning the unchanged list', async () => {
    getWalletNFTs.mockResolvedValueOnce(moralisPage([1], 'cursor-page2'));
    await repository.findByAddress({ address: ADDRESS_A, chainId: CHAIN_ID, refresh: true });

    getWalletNFTs.mockRejectedValueOnce(new Error('rate limited'));

    // Returning the accumulated list here is indistinguishable from "no more NFTs" and
    // would retire the caller's "load more" button while the cursor is still good
    await expect(repository.findByAddress({ address: ADDRESS_A, chainId: CHAIN_ID, refresh: false })).rejects.toThrow(
      'rate limited',
    );
  });

  it('keeps already-fetched pages and the cursor after a failed page', async () => {
    getWalletNFTs.mockResolvedValueOnce(moralisPage([1], 'cursor-page2'));
    await repository.findByAddress({ address: ADDRESS_A, chainId: CHAIN_ID, refresh: true });

    getWalletNFTs.mockRejectedValueOnce(new Error('rate limited'));
    await expect(repository.findByAddress({ address: ADDRESS_A, chainId: CHAIN_ID, refresh: false })).rejects.toThrow();

    // The first page survives the failed second page and the cursor is retried next call
    getWalletNFTs.mockResolvedValueOnce(moralisPage([2], null));
    const retried = await repository.findByAddress({ address: ADDRESS_A, chainId: CHAIN_ID, refresh: false });
    expect(retried).toEqual([
      { tokenId: 1, chainId: CHAIN_ID },
      { tokenId: 2, chainId: CHAIN_ID },
    ]);
    expect(getWalletNFTs).toHaveBeenLastCalledWith(expect.objectContaining({ cursor: 'cursor-page2' }));
  });

  it('hands out a copy, so a caller cannot rewrite the cached pages', async () => {
    getWalletNFTs.mockResolvedValueOnce(moralisPage([1, 2], 'cursor-next'));
    const first = await repository.findByAddress({ address: ADDRESS_A, chainId: CHAIN_ID, refresh: true });
    expect(first).toHaveLength(2);

    // This is a server-side singleton shared by every request, so a caller mutating what
    // it returns would rewrite one wallet's cached pages for everyone who asks next
    first.length = 0;
    first.push({ tokenId: 999, chainId: CHAIN_ID } as never);

    getWalletNFTs.mockResolvedValueOnce(moralisPage([3], null));
    const second = await repository.findByAddress({ address: ADDRESS_A, chainId: CHAIN_ID, refresh: false });

    expect(second).toEqual([
      { tokenId: 1, chainId: CHAIN_ID },
      { tokenId: 2, chainId: CHAIN_ID },
      { tokenId: 3, chainId: CHAIN_ID },
    ]);
  });

  describe('cache eviction', () => {
    /** A distinct wallet address for index n */
    const walletN = (n: number) => `0x${n.toString(16).padStart(40, '0')}` as Address;

    /** Leaves the wallet holding a cursor, so its pagination state is worth keeping */
    const seed = async (address: Address, cursor: string) => {
      getWalletNFTs.mockResolvedValueOnce(moralisPage([1], cursor));
      await repository.findByAddress({ address, chainId: CHAIN_ID, refresh: true });
    };

    it('does not evict anyone when an existing wallet refreshes', async () => {
      for (let n = 0; n < MAX_CACHED_WALLETS; n++) {
        await seed(walletN(n), `cursor-${n}`);
      }

      // A refresh replaces an entry that is already there, so the cache does not grow and
      // nothing needs evicting. The old code ran the eviction anyway and took out the
      // oldest wallet, which had done nothing wrong
      await seed(walletN(250), 'cursor-250-refreshed');

      getWalletNFTs.mockResolvedValueOnce(moralisPage([3], null));
      await repository.findByAddress({ address: walletN(0), chainId: CHAIN_ID, refresh: false });

      expect(getWalletNFTs).toHaveBeenLastCalledWith(expect.objectContaining({ cursor: 'cursor-0' }));
    });

    it('evicts the least recently used wallet, not the first one inserted', async () => {
      // Given: the cache is full
      for (let n = 0; n < MAX_CACHED_WALLETS; n++) {
        await seed(walletN(n), `cursor-${n}`);
      }

      // And: the oldest-inserted wallet is used again, which should renew it
      getWalletNFTs.mockResolvedValueOnce(moralisPage([2], 'cursor-0-page3'));
      await repository.findByAddress({ address: walletN(0), chainId: CHAIN_ID, refresh: false });

      // When: a new wallet arrives and forces an eviction
      await seed(walletN(MAX_CACHED_WALLETS), 'cursor-new');

      // Then: wallet 0 still has its cursor. Evicting by insertion order dropped the
      // wallet part-way through pagination and restarted it from the first page
      getWalletNFTs.mockResolvedValueOnce(moralisPage([3], null));
      await repository.findByAddress({ address: walletN(0), chainId: CHAIN_ID, refresh: false });

      expect(getWalletNFTs).toHaveBeenLastCalledWith(expect.objectContaining({ cursor: 'cursor-0-page3' }));
    });
  });

  it('does not cache a failure as complete', async () => {
    getWalletNFTs.mockRejectedValueOnce(new Error('rate limited'));
    await expect(repository.findByAddress({ address: ADDRESS_A, chainId: CHAIN_ID, refresh: true })).rejects.toThrow();

    // A retry goes back to the API instead of reporting the wallet as fully fetched
    getWalletNFTs.mockResolvedValueOnce(moralisPage([7], null));
    const retried = await repository.findByAddress({ address: ADDRESS_A, chainId: CHAIN_ID, refresh: false });
    expect(retried).toEqual([{ tokenId: 7, chainId: CHAIN_ID }]);
  });
});

describe('a hung Moralis request', () => {
  const ADDRESS_C = '0x3333333333333333333333333333333333333333' as Address;

  beforeEach(() => {
    getWalletNFTs.mockReset();
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('is abandoned instead of holding the wallet queue for good', async () => {
    // Never settles. Without a bound this held every later request for this wallet behind
    // it for the life of the process; bounding the queue *wait* instead would have let a
    // second fetch run against the same cursor, which is what the queue exists to prevent
    getWalletNFTs.mockReturnValueOnce(new Promise(() => {}) as never);

    const hung = repository.findByAddress({ address: ADDRESS_C, chainId: CHAIN_ID, refresh: true });
    const settled = expect(hung).rejects.toThrow('timed out');
    await vi.advanceTimersByTimeAsync(PAGE_REQUEST_TIMEOUT_MS);
    await settled;

    // The queue moved on, and the abandoned page is simply refetched
    getWalletNFTs.mockResolvedValueOnce(moralisPage([7], null));
    await expect(repository.findByAddress({ address: ADDRESS_C, chainId: CHAIN_ID, refresh: false })).resolves.toEqual([
      { tokenId: 7, chainId: CHAIN_ID },
    ]);
  });

  it('leaves the cursor untouched, so no page is skipped', async () => {
    getWalletNFTs.mockResolvedValueOnce(moralisPage([1], 'cursor-1'));
    await repository.findByAddress({ address: ADDRESS_C, chainId: CHAIN_ID, refresh: true });

    getWalletNFTs.mockReturnValueOnce(new Promise(() => {}) as never);
    const hung = repository.findByAddress({ address: ADDRESS_C, chainId: CHAIN_ID, refresh: false });
    const settled = expect(hung).rejects.toThrow('timed out');
    await vi.advanceTimersByTimeAsync(PAGE_REQUEST_TIMEOUT_MS);
    await settled;

    getWalletNFTs.mockResolvedValueOnce(moralisPage([2], null));
    await repository.findByAddress({ address: ADDRESS_C, chainId: CHAIN_ID, refresh: false });

    expect(getWalletNFTs).toHaveBeenLastCalledWith(expect.objectContaining({ cursor: 'cursor-1' }));
  });
});

describe('a page whose NFTs cannot be mapped', () => {
  const ADDRESS_D = '0x4444444444444444444444444444444444444444' as Address;
  const mapper = vi.mocked(mapToNFTFromMoralis);

  beforeEach(() => {
    getWalletNFTs.mockReset();
  });

  it('does not advance the cursor past it', async () => {
    // Given: a first page that maps, leaving a cursor
    getWalletNFTs.mockResolvedValueOnce(moralisPage([1], 'cursor-d-page2'));
    await repository.findByAddress({ address: ADDRESS_D, chainId: CHAIN_ID, refresh: true });

    // When: the second page comes back but one of its items cannot be mapped
    getWalletNFTs.mockResolvedValueOnce(moralisPage([2], 'cursor-d-page3'));
    mapper.mockImplementationOnce(() => {
      throw new Error('malformed NFT');
    });
    await expect(repository.findByAddress({ address: ADDRESS_D, chainId: CHAIN_ID, refresh: false })).rejects.toThrow(
      'malformed NFT',
    );

    // Then: the retry refetches that same page rather than skipping to the one after it
    getWalletNFTs.mockResolvedValueOnce(moralisPage([2], null));
    const retried = await repository.findByAddress({ address: ADDRESS_D, chainId: CHAIN_ID, refresh: false });

    expect(getWalletNFTs).toHaveBeenLastCalledWith(expect.objectContaining({ cursor: 'cursor-d-page2' }));
    expect(retried).toEqual([
      { tokenId: 1, chainId: CHAIN_ID },
      { tokenId: 2, chainId: CHAIN_ID },
    ]);
  });

  it('does not mark the wallet as fully fetched', async () => {
    // A last page (no cursor) that fails to map used to set hasFetchedAll before mapping,
    // so every later call returned the list without it and never went back to the API
    getWalletNFTs.mockResolvedValueOnce(moralisPage([1], null));
    mapper.mockImplementationOnce(() => {
      throw new Error('malformed NFT');
    });
    await expect(repository.findByAddress({ address: ADDRESS_D, chainId: CHAIN_ID, refresh: true })).rejects.toThrow(
      'malformed NFT',
    );

    getWalletNFTs.mockResolvedValueOnce(moralisPage([1], null));
    const retried = await repository.findByAddress({ address: ADDRESS_D, chainId: CHAIN_ID, refresh: false });

    expect(retried).toEqual([{ tokenId: 1, chainId: CHAIN_ID }]);
  });
});
