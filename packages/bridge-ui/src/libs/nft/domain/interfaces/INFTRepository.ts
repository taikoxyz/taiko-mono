import type { NFT } from '$nftAPI/domain/models/NFT';
import type { FetchNftArgs } from '$nftAPI/infrastructure/types/common';

export interface INFTRepository {
  findByAddress({ address, chainId, refresh }: FetchNftArgs): Promise<NFT[]>;
}
