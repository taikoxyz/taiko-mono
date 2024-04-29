// src/lib/infrastructure/api/NFTRepository.server.ts
import Moralis from 'moralis';
import type { Address } from 'viem';

import { MORALIS_API_KEY } from '$env/static/private';

import type { INFTRepository } from '../../domain/interfaces/INFTRepository';
import type { NFT } from '../../domain/models/NFT';
import { mapToNFTFromMoralis } from '../mappers/nft/MoralisNFTMapper';
import type { NFTApiData } from '../types/moralis';

class MoralisNFTRepository implements INFTRepository {
  private static instance: MoralisNFTRepository;

  private constructor() {
    Moralis.start({
      apiKey: MORALIS_API_KEY,
    }).catch(console.error);
  }

  public static getInstance(): MoralisNFTRepository {
    if (!MoralisNFTRepository.instance) {
      MoralisNFTRepository.instance = new MoralisNFTRepository();
    }
    return MoralisNFTRepository.instance;
  }

  async findByAddress(address: Address, chainId: number): Promise<NFT[]> {
    try {
      const response = await Moralis.EvmApi.nft.getWalletNFTs({
        chain: chainId,
        format: 'decimal',
        excludeSpam: true,
        mediaItems: false,
        address: address,
      });

      return response.result.map((nft) => mapToNFTFromMoralis(nft as unknown as NFTApiData, chainId));
    } catch (e) {
      console.error('Failed to fetch NFTs from Moralis:', e);
      return [];
    }
  }
}

export default MoralisNFTRepository.getInstance();
