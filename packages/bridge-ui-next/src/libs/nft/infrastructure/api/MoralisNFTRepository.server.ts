import "server-only";

import Moralis from "moralis";
import type { Address } from "viem";

import { moralisApiConfig } from "$config";
import type { INFTRepository } from "$nftAPI/domain/interfaces/INFTRepository";
import type { NFT } from "$nftAPI/domain/models/NFT";
import { mapToNFTFromMoralis } from "$nftAPI/infrastructure/mappers/nft/MoralisNFTMapper";
import type { NFTApiData } from "$nftAPI/infrastructure/types/moralis";

import type { FetchNftArgs } from "../types/common";

// SvelteKit `$env/static/private` MORALIS_API_KEY -> Next.js server-only process.env.
// Never expose this on the client; this module is `server-only`.
const MORALIS_API_KEY = process.env.MORALIS_API_KEY ?? "";

// The repository is a process-wide singleton serving every request to
// /api/nft, so pagination state MUST be keyed per (chain, address): a shared
// cursor/list would leak one wallet's NFTs to other callers.
type CacheEntry = {
  cursor: string;
  hasFetchedAll: boolean;
  nfts: NFT[];
};

// Simple insertion-order eviction bound so the per-wallet cache cannot grow
// without limit on a long-lived server process.
const MAX_CACHE_ENTRIES = 500;

class MoralisNFTRepository implements INFTRepository {
  private static instance: MoralisNFTRepository;
  private static isInitialized = false;

  private cache = new Map<string, CacheEntry>();

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

  async findByAddress({
    address,
    chainId,
    refresh = false,
  }: FetchNftArgs): Promise<NFT[]> {
    const key = MoralisNFTRepository.cacheKey(chainId, address);
    if (refresh) {
      this.cache.delete(key);
    }

    const cached = this.cache.get(key);
    if (cached?.hasFetchedAll) {
      return cached.nfts;
    }

    try {
      const response = await Moralis.EvmApi.nft.getWalletNFTs({
        cursor: cached?.cursor ?? "",
        chain: chainId,
        excludeSpam: moralisApiConfig.excludeSpam,
        mediaItems: moralisApiConfig.mediaItems,
        address: address,
        limit: moralisApiConfig.limit,
      });

      const cursor = response.pagination.cursor || "";
      const mappedData = response.result.map((nft) =>
        mapToNFTFromMoralis(nft as unknown as NFTApiData, chainId),
      );
      const nfts = [...(cached?.nfts ?? []), ...mappedData];

      this.cache.set(key, {
        cursor,
        hasFetchedAll: !cursor, // no cursor -> all pages fetched
        nfts,
      });
      this.evictIfOverCapacity();

      return nfts;
    } catch (e) {
      console.error("Failed to fetch NFTs from Moralis:", e);
      return [];
    }
  }

  private static cacheKey(chainId: number, address: Address): string {
    return `${chainId}:${address.toLowerCase()}`;
  }

  private evictIfOverCapacity(): void {
    while (this.cache.size > MAX_CACHE_ENTRIES) {
      const oldestKey = this.cache.keys().next().value;
      if (oldestKey === undefined) return;
      this.cache.delete(oldestKey);
    }
  }
}

export default MoralisNFTRepository.getInstance();
