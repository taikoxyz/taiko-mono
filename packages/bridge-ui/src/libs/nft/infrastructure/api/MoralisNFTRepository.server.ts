import Moralis from 'moralis';
import type { Address } from 'viem';

import { moralisApiConfig } from '$config';
import { MORALIS_API_KEY } from '$env/static/private';
import type { INFTRepository } from '$nftAPI/domain/interfaces/INFTRepository';
import type { NFT } from '$nftAPI/domain/models/NFT';
import { mapToNFTFromMoralis } from '$nftAPI/infrastructure/mappers/nft/MoralisNFTMapper';
import type { NFTApiData } from '$nftAPI/infrastructure/types/moralis';

import type { FetchNftArgs } from '../types/common';

type PaginationState = {
  cursor: string;
  hasFetchedAll: boolean;
  nfts: NFT[];
};

// The repository is a server-side singleton shared by every request, so pagination state must be
// keyed per wallet+chain — module-level cursor/nft state would leak one user's NFTs to another.
export const MAX_CACHED_WALLETS = 500;

/**
 * How long one page request may take before it is abandoned.
 *
 * The bound is on the request, not on the queue wait ahead of it. An earlier attempt raced
 * the wait against a timer, which let a second fetch start against the same
 * PaginationState - one cursor read twice, one page appended twice, the exact corruption
 * the queue exists to prevent. Timing out the request instead keeps the queue strictly
 * serial: an abandoned request mutates nothing (every write happens after the await), so
 * the cursor is untouched and the next call simply refetches that page.
 */
export const PAGE_REQUEST_TIMEOUT_MS = 30_000;

/**
 * @dev Rejects if the given promise has not settled within PAGE_REQUEST_TIMEOUT_MS.
 *
 *      Promise.race attaches a handler to both sides, so neither the abandoned request nor
 *      the losing timer can surface as an unhandled rejection; the timer is cleared either
 *      way so it never fires after the race is decided.
 *
 * @param promise The request to bound
 * @return result_ Whatever the request resolved to, if it did so in time
 */
async function withTimeout<T>(promise: Promise<T>): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const expiry = new Promise<never>((_, reject) => {
    timer = setTimeout(
      () => reject(new Error(`Moralis request timed out after ${PAGE_REQUEST_TIMEOUT_MS}ms`)),
      PAGE_REQUEST_TIMEOUT_MS,
    );
  });
  try {
    return await Promise.race([promise, expiry]);
  } finally {
    clearTimeout(timer);
  }
}

class MoralisNFTRepository implements INFTRepository {
  private static instance: MoralisNFTRepository;
  private static isInitialized = false;

  private stateByWallet: Map<string, PaginationState> = new Map();
  /**
   * At most one entry per wallet+chain, deleted when its request settles (see releaseSlot
   * below), so this holds only what is genuinely in flight. It needs no MAX_CACHED_WALLETS
   * of its own: a cap here could only be enforced by refusing requests.
   */
  private requestQueueByWallet: Map<string, Promise<NFT[]>> = new Map();

  private constructor() {
    if (!MoralisNFTRepository.isInitialized) {
      Moralis.start({ apiKey: MORALIS_API_KEY })
        .then(() => {
          MoralisNFTRepository.isInitialized = true;
        })
        .catch(console.error);
    }
  }

  public static getInstance(): MoralisNFTRepository {
    if (!MoralisNFTRepository.instance) {
      MoralisNFTRepository.instance = new MoralisNFTRepository();
    }
    return MoralisNFTRepository.instance;
  }

  async findByAddress({ address, chainId, refresh = false }: FetchNftArgs): Promise<NFT[]> {
    const key = `${address.toLowerCase()}-${chainId}`;

    // Serialize requests per wallet+chain: concurrent calls would read the same cursor,
    // fetch the same page twice, and append duplicates to the shared pagination state
    const previous = this.requestQueueByWallet.get(key) ?? Promise.resolve([]);
    // Strictly serialized, and every entry is bounded by PAGE_REQUEST_TIMEOUT_MS, so a
    // hung Moralis call cannot hold this wallet's queue for the life of the process
    const request = previous.catch(() => []).then(() => this.fetchNextPage({ address, chainId, refresh }));
    this.requestQueueByWallet.set(key, request);

    const releaseSlot = () => {
      if (this.requestQueueByWallet.get(key) === request) {
        this.requestQueueByWallet.delete(key);
      }
    };
    // `.finally()` would build a derived promise that rejects with no handler attached
    // once a failed page propagates; passing the same callback to both arms of `.then()`
    // settles that promise either way. The caller still sees the rejection via `request`.
    void request.then(releaseSlot, releaseSlot);

    return request;
  }

  private async fetchNextPage({ address, chainId, refresh = false }: FetchNftArgs): Promise<NFT[]> {
    const state = this.getState(address, chainId, refresh);

    // A copy, not the array itself. This is a server-side singleton shared by every
    // request, so handing out the stored array lets any caller's mutation rewrite one
    // wallet's cached pages for everyone who asks next
    if (state.hasFetchedAll) {
      return [...state.nfts];
    }

    try {
      const response = await withTimeout(
        Moralis.EvmApi.nft.getWalletNFTs({
          cursor: state.cursor,
          chain: chainId,
          excludeSpam: moralisApiConfig.excludeSpam,
          mediaItems: moralisApiConfig.mediaItems,
          address: address,
          limit: moralisApiConfig.limit,
        }),
      );

      // Map before touching the state. Advancing the cursor first meant a mapping that threw
      // on a malformed item left the cursor past a page whose NFTs were never appended, so
      // the retry below skipped it - and if that page was the last one, `hasFetchedAll` was
      // already true and the gap became permanent until a refresh.
      const mappedData = response.result.map((nft) => mapToNFTFromMoralis(nft as unknown as NFTApiData, chainId));

      state.cursor = response.pagination.cursor || '';
      state.hasFetchedAll = !state.cursor; // If there is no cursor, we have fetched all NFTs
      state.nfts = [...state.nfts, ...mappedData];
      return [...state.nfts];
    } catch (e) {
      console.error('Failed to fetch NFTs from Moralis:', e);
      // The accumulated pages and the cursor stay in `state`, so the failed page is
      // retried on the next call. The failure itself has to reach the caller: returning
      // the unchanged list looks exactly like "no more NFTs" and would retire the
      // "load more" button while the cursor is still good.
      throw e;
    }
  }

  private getState(address: Address, chainId: number, refresh: boolean): PaginationState {
    const key = `${address.toLowerCase()}-${chainId}`;
    let state = this.stateByWallet.get(key);

    if (!state || refresh) {
      state = { cursor: '', hasFetchedAll: false, nfts: [] };
      // Delete first: setting an existing key leaves its position in the Map untouched, so
      // a refreshed wallet kept whatever position it had and could be evicted by the very
      // next arrival despite having just been used
      this.stateByWallet.delete(key);
      this.evictLeastRecentlyUsedIfFull();
      this.stateByWallet.set(key, state);
      return state;
    }

    // Move to the end so eviction follows use rather than insertion order. Without this a
    // wallet part-way through pagination could be evicted ahead of one that fetched once
    // and left, and it would restart from the first page
    this.stateByWallet.delete(key);
    this.stateByWallet.set(key, state);
    return state;
  }

  /**
   * @dev Map iteration is insertion-ordered, and getState re-inserts on every hit, so the
   *      first match of each pass below is the least recently used of its kind.
   *
   *      A finished wallet is evicted before one still walking its pages. Evicting mid-walk
   *      drops that wallet's cursor, and the restart is not harmless: the next "load more"
   *      begins at page one and returns what is already on screen, so `nextPage` sees no
   *      growth, reports that nothing arrived, and ScannedImport retires the button until a
   *      refresh. This endpoint is unauthenticated, so the churn needed to force that is
   *      cheap to produce; preferring completed sessions keeps the cache bounded without
   *      making an in-progress walk the easiest thing to throw away.
   */
  private evictLeastRecentlyUsedIfFull(): void {
    if (this.stateByWallet.size < MAX_CACHED_WALLETS) return;

    for (const [key, state] of this.stateByWallet) {
      if (state.hasFetchedAll) {
        this.stateByWallet.delete(key);
        return;
      }
    }

    // Every entry is mid-walk, so the cap has to be honoured at the oldest one's expense
    const leastRecentlyUsedKey = this.stateByWallet.keys().next().value;
    if (leastRecentlyUsedKey !== undefined) {
      this.stateByWallet.delete(leastRecentlyUsedKey);
    }
  }
}

export default MoralisNFTRepository.getInstance();
