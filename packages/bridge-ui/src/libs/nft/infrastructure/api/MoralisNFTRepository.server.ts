import Moralis from 'moralis';
import { type Address, zeroAddress } from 'viem';

import { moralisApiConfig } from '$config';
import { MORALIS_API_KEY } from '$env/static/private';
import type { INFTRepository } from '$nftAPI/domain/interfaces/INFTRepository';
import type { NFT } from '$nftAPI/domain/models/NFT';
import { mapToNFTFromMoralis } from '$nftAPI/infrastructure/mappers/nft/MoralisNFTMapper';
import type { NFTApiData } from '$nftAPI/infrastructure/types/moralis';

import type { FetchNftArgs } from '../types/common';

class MoralisNFTRepository implements INFTRepository {
  private static instance: MoralisNFTRepository;
  private static isInitialized = false;

  private cursor: string;
  private lastFetchedAddress: Address;
  private hasFetchedAll: boolean;
  private nfts: NFT[] = [];

  private constructor() {
    if (!MoralisNFTRepository.isInitialized) {
      Moralis.start({ apiKey: MORALIS_API_KEY })
        .then(() => {
          MoralisNFTRepository.isInitialized = true;
        })
        .catch(console.error);
    }

    this.cursor = '';
    this.lastFetchedAddress = zeroAddress;
    this.hasFetchedAll = false;
  }

  public static getInstance(): MoralisNFTRepository {
    if (!MoralisNFTRepository.instance) {
      MoralisNFTRepository.instance = new MoralisNFTRepository();
    }
    return MoralisNFTRepository.instance;
  }

  async findByAddress({ address, chainId, refresh = false }: FetchNftArgs): Promise<NFT[]> {
    this.lastFetchedAddress = address;
    if (refresh) {
      this.reset();
    }
    if (this.hasFetchedAll) {
      return this.nfts;
    }

    try {
      const response = await Moralis.EvmApi.nft.getWalletNFTs({
        cursor: this.getCursor(address, refresh),
        chain: chainId,
        excludeSpam: moralisApiConfig.excludeSpam,
        mediaItems: moralisApiConfig.mediaItems,
        address: address,
        limit: moralisApiConfig.limit,
      });

      this.cursor = response.pagination.cursor || '';
      this.hasFetchedAll = !this.cursor; // If there is no cursor, we have fetched all NFTs

      const mappedData = response.result.map((nft) => mapToNFTFromMoralis(nft as unknown as NFTApiData, chainId));
      this.nfts = [...this.nfts, ...mappedData];
      return this.nfts;
    } catch (e) {
      console.error('Failed to fetch NFTs from Moralis:', e);
      return [];
    }
  }

  private reset(): void {
    this.cursor = '';
    this.hasFetchedAll = false;
    this.nfts = [];
  }

  private getCursor(address: Address, refresh: boolean): string {
    if (this.lastFetchedAddress !== address || refresh) {
      return '';
    }
    return this.cursor || '';
  }
}

export default MoralisNFTRepository.getInstance();
