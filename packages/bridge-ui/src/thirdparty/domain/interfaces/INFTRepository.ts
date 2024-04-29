import type { NFT } from '../models/NFT';

export interface INFTRepository {
  findByAddress(address: string, chainId: number): Promise<NFT[]>;
}
