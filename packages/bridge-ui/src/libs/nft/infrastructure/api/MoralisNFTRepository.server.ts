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
const MAX_CACHED_WALLETS = 500;

class MoralisNFTRepository implements INFTRepository {
  private static instance: MoralisNFTRepository;
  private static isInitialized = false;

  private stateByWallet: Map<string, PaginationState> = new Map();

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
    const state = this.getState(address, chainId, refresh);

    if (state.hasFetchedAll) {
      return state.nfts;
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
      return state.nfts;
    } catch (e) {
      console.error('Failed to fetch NFTs from Moralis:', e);
      return [];
    }
  }

  private getState(address: Address, chainId: number, refresh: boolean): PaginationState {
    const key = `${address.toLowerCase()}-${chainId}`;
    let state = this.stateByWallet.get(key);

    if (!state || refresh) {
      state = { cursor: '', hasFetchedAll: false, nfts: [] };
      this.evictOldestIfFull();
      this.stateByWallet.set(key, state);
    }
    return state;
  }

  private evictOldestIfFull(): void {
    if (this.stateByWallet.size < MAX_CACHED_WALLETS) return;
    const oldestKey = this.stateByWallet.keys().next().value;
    if (oldestKey !== undefined) {
      this.stateByWallet.delete(oldestKey);
    }
  }
}

export default MoralisNFTRepository.getInstance();
