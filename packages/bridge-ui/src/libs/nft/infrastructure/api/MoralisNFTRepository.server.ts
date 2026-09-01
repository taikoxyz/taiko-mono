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

class MoralisNFTRepository implements INFTRepository {
  private static instance: MoralisNFTRepository;
  private static isInitialized = false;

  private stateByWallet: Map<string, PaginationState> = new Map();
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
      const response = await Moralis.EvmApi.nft.getWalletNFTs({
        cursor: state.cursor,
        chain: chainId,
        excludeSpam: moralisApiConfig.excludeSpam,
        mediaItems: moralisApiConfig.mediaItems,
        address: address,
        limit: moralisApiConfig.limit,
      });

      state.cursor = response.pagination.cursor || '';
      state.hasFetchedAll = !state.cursor; // If there is no cursor, we have fetched all NFTs

      const mappedData = response.result.map((nft) => mapToNFTFromMoralis(nft as unknown as NFTApiData, chainId));
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

  /** @dev Map iteration is insertion-ordered, and getState re-inserts on every hit */
  private evictLeastRecentlyUsedIfFull(): void {
    if (this.stateByWallet.size < MAX_CACHED_WALLETS) return;
    const leastRecentlyUsedKey = this.stateByWallet.keys().next().value;
    if (leastRecentlyUsedKey !== undefined) {
      this.stateByWallet.delete(leastRecentlyUsedKey);
    }
  }
}

export default MoralisNFTRepository.getInstance();
