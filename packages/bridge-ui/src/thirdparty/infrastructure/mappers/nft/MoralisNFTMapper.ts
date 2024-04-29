import type { NFT } from 'src/thirdparty/domain/models/NFT';
import type { Address } from 'viem';

import type { TokenType } from '$libs/token';

import type { NFTApiData } from '../../types/moralis';

export function mapToNFTFromMoralis(apiData: NFTApiData, chainId: number): NFT {
  return {
    tokenId: apiData.tokenId,
    uri: apiData.tokenUri,
    owner: apiData.ownerOf as Address,
    name: apiData.name,
    symbol: apiData.symbol,
    type: apiData.contractType as TokenType,
    addresses: {
      [chainId]: apiData.tokenAddress as Address,
    },
  };
}
