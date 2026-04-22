import type { Address } from 'viem';

import { isL2Chain } from '$libs/chain';
import { eventIndexerApiServices } from '$libs/eventIndexer/initEventIndexer';
import { type NFT, TokenType } from '$libs/token';
import { fetchNFTImageUrl } from '$libs/token/fetchNFTImageUrl';
import { getTokenWithInfoFromAddress } from '$libs/token/getTokenWithInfoFromAddress';
import { getLogger } from '$libs/util/logger';
import type { FetchNftArgs } from '$nftAPI/infrastructure/types/common';

const log = getLogger('bridge:fetchNFTs');

export const fetchNFTs = async ({
  address: userAddress,
  chainId: srcChainId,
  refresh,
}: FetchNftArgs): Promise<{ nfts: NFT[]; error: Error | null }> => {
  let nfts: NFT[] = [];
  try {
    if (isL2Chain(srcChainId)) {
      // Todo: replace with a third party service once available
      // right now we have to use our own indexer for L2
      nfts = await fetchL2NFTs({ userAddress, srcChainId, refresh });
    } else {
      nfts = await fetchL1NFTs({ userAddress, srcChainId, refresh });
    }

    const promises = Promise.all(
      nfts.map(async (nft: NFT) => {
        const nftWithImage = await fetchNFTImageUrl(nft);
        return nftWithImage;
      }),
    );

    const nftsWithImage = await promises;
    nfts = nftsWithImage;
    return { nfts, error: null };
  } catch (error) {
    console.error('Fetch error:', error);
    return { nfts: [], error: new Error('') };
  }
};

const fetchL1NFTs = async ({
  userAddress,
  srcChainId,
  refresh,
}: {
  userAddress: Address;
  srcChainId: number;
  refresh: boolean;
}) => {
  log('fetching L1 NFTs', { userAddress, srcChainId, refresh });
  const moralisResponse = await fetch('/api/nft', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ address: userAddress, chainId: srcChainId, refresh }),
  });

  if (moralisResponse.ok) {
    const responseData = await moralisResponse.json();
    log('cursor', responseData);
    const { nfts } = responseData;

    return nfts;
  } else {
    console.error('HTTP error:', moralisResponse.statusText);
    return { nfts: [], error: new Error(moralisResponse.statusText) };
  }
};

const fetchL2NFTs = async ({
  userAddress,
  srcChainId,
  refresh,
}: {
  userAddress: Address;
  srcChainId: number;
  refresh: boolean;
}) => {
  log('fetching L2 NFTs', { userAddress, srcChainId, refresh });
  const indexerPromises: Promise<NFT[]>[] = eventIndexerApiServices.map(async (eventIndexerApiService) => {
    const { items: result } = await eventIndexerApiService.getAllNftsByAddressFromAPI(userAddress, BigInt(srcChainId), {
      page: 0,
      size: 100,
    });

    const nftsPromises: Promise<NFT>[] = result.map(async (nft) => {
      const type: TokenType = TokenType[nft.contractType as keyof typeof TokenType];
      return getTokenWithInfoFromAddress({
        contractAddress: nft.contractAddress,
        srcChainId,
        owner: userAddress,
        tokenId: Number(nft.tokenID),
        type,
      }) as Promise<NFT>;
    });

    const nftsSettled = await Promise.allSettled(nftsPromises);
    const nfts = nftsSettled
      .filter((result) => result.status === 'fulfilled')
      .map((result) => (result as PromiseFulfilledResult<NFT>).value);

    return nfts;
  });

  let nftArrays: NFT[][] = [];
  try {
    nftArrays = await Promise.all(indexerPromises);
  } catch (e) {
    log('error fetching nfts from indexer services', e);
    throw e;
  }
  return deduplicateNFTs(nftArrays);
};

// Deduplicate based on address and chainID
function deduplicateNFTs(nftArrays: NFT[][]): NFT[] {
  const nftMap: Map<string, NFT> = new Map();
  nftArrays.flat().forEach((nft) => {
    Object.entries(nft.addresses).forEach(([chainID, address]) => {
      const uniqueKey = `${address}-${chainID}-${nft.tokenId}`;

      if (!nftMap.has(uniqueKey)) {
        nftMap.set(uniqueKey, nft);
      }
    });
  });
  return Array.from(nftMap.values());
}
