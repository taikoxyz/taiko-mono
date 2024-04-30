import type { NFT } from '$api/domain/models/NFT';
import type { FetchNftArgs } from '$api/infrastructure/types/common';

export interface INFTRepository {
  findByAddress({ address, chainId, refresh }: FetchNftArgs): Promise<NFT[]>;
}
