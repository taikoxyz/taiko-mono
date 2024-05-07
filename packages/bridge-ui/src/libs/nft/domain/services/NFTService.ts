import type { Address } from 'viem';

import type { INFTRepository } from '../interfaces/INFTRepository';
import type { NFT } from '../models/NFT';

export class NFTService {
  constructor(private repository: INFTRepository) {}

  async fetchNFTsByAddress({
    address,
    chainId,
    refresh,
  }: {
    address: Address;
    chainId: number;
    refresh: boolean;
  }): Promise<NFT[]> {
    return await this.repository.findByAddress({ address, chainId, refresh });
  }
}
