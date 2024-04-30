import type { Address } from 'viem';

import type { NFT } from '$api/domain/models/NFT';
import type { NFTApiData } from '$api/infrastructure/types/moralis';
import type { TokenType } from '$libs/token';

export function mapToNFTFromMoralis(apiData: NFTApiData, chainId: number): NFT {
  return {
    tokenId: apiData.tokenId,
    uri: apiData.tokenUri,
    owner: apiData.ownerOf as Address,
    name: apiData.name,
    symbol: apiData.symbol,
    type: apiData.contractType as TokenType,
    balance: apiData.amount,
    addresses: {
      [chainId]: apiData.tokenAddress as Address,
    },
  };
}
