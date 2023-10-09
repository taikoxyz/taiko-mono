import type { Address } from 'viem';

import type { ChainID } from '$libs/chain';
import { eventIndexerApiServices } from '$libs/eventIndexer/initEventIndexer';
import { type NFT, TokenType } from '$libs/token';
import { getTokenWithInfoFromAddress } from '$libs/token/getTokenWithInfoFromAddress';
import { getLogger } from '$libs/util/logger';

const log = getLogger('bridge:fetchNFTs');

function deduplicateNFTs(nftArrays: NFT[][]): NFT[] {
  const nftMap: Map<string, NFT> = new Map();
  nftArrays.flat().forEach((nft) => {
    Object.entries(nft.addresses).forEach(([chainID, address]) => {
      const uniqueKey = `${address}-${chainID}`;
      if (!nftMap.has(uniqueKey)) {
        nftMap.set(uniqueKey, nft);
      }
    });
  });
  return Array.from(nftMap.values());
}

export async function fetchNFTs(userAddress: Address, chainID: ChainID): Promise<{ nfts: NFT[]; error: Error | null }> {
  let error: Error | null = null;

  // Fetch from all indexers
  const indexerPromises: Promise<NFT[]>[] = eventIndexerApiServices.map(async (eventIndexerApiService) => {
    const { items: result } = await eventIndexerApiService.getAllNftsByAddressFromAPI(userAddress, chainID, {
      page: 0,
      size: 100,
    });

    const nftsPromises: Promise<NFT>[] = result.map(async (nft) => {
      const type: TokenType = TokenType[nft.contractType as keyof typeof TokenType];
      //TODO: tokenID should not be cast to number, but the ABI only allows for numbers, so it would fail either way if it wasn't a number
      return (await getTokenWithInfoFromAddress({
        contractAddress: nft.contractAddress,
        srcChainId: Number(chainID),
        owner: userAddress,
        tokenId: Number(nft.tokenID),
        type,
      })) as NFT;
    });
    return await Promise.all(nftsPromises);
  });

  let nftArrays: NFT[][] = [];
  try {
    nftArrays = await Promise.all(indexerPromises);
  } catch (e) {
    log('error fetching nfts from indexer services', e);
    error = e as Error;
  }

  // Deduplicate based on address and chainID
  const deduplicatedNfts = deduplicateNFTs(nftArrays);

  log(`found ${deduplicatedNfts.length} unique NFTs from all indexers`, deduplicatedNfts);

  return { nfts: deduplicatedNfts, error };
}
