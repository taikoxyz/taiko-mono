import type { INFTRepository } from '../interfaces/INFTRepository';
import type { NFT } from '../models/NFT';

export class NFTService {
  constructor(private repository: INFTRepository) {}

  async fetchNFTsByAddress(address: string, chainId: number): Promise<NFT[]> {
    return await this.repository.findByAddress(address, chainId);
  }
}
