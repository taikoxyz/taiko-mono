import type { Address } from 'viem';

import type { ChainID } from '$libs/chain';
import { eventIndexerApiServices } from '$libs/eventIndexer/initEventIndexer';
import { type Token, TokenType } from '$libs/token';
import { getTokenInfoFromAddress } from '$libs/token/getTokenInfo';
import { getLogger } from '$libs/util/logger';

const log = getLogger('bridge:fetchNFTs');

function deduplicateNFTs(nftArrays: Token[][]): Token[] {
  const nftMap: Map<string, Token> = new Map();
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

export async function fetchNFTs(
  userAddress: Address,
  chainID: ChainID,
): Promise<{ nfts: Token[]; error: Error | null }> {
  let error: Error | null = null;

  // Fetch from all indexers
  const indexerPromises: Promise<Token[]>[] = eventIndexerApiServices.map(async (eventIndexerApiService) => {
    const { nfts: result = [] } = await eventIndexerApiService.getAllNftsByAddressFromAPI(userAddress, chainID, {
      page: 0,
      size: 100,
    });
    const nftsPromises: Promise<Token>[] = result.map(async (nft) => {
      const type: TokenType = TokenType[nft.ContractType as keyof typeof TokenType];
      const { name, symbol, decimals } = await getTokenInfoFromAddress(nft.ContractAddress);
      return {
        id: nft.TokenID,
        chainID: nft.ChainID,
        addresses: {
          [nft.ChainID]: nft.ContractAddress,
        },
        type,
        name,
        symbol,
        decimals,
      };
    });
    return await Promise.all(nftsPromises);
  });

  let nftArrays: Token[][] = [];
  try {
    nftArrays = await Promise.all(indexerPromises);
  } catch (e) {
    log('error fetching transactions from relayers', e);
    error = e as Error;
  }

  // Deduplicate based on address and chainID
  const deduplicatedNfts = deduplicateNFTs(nftArrays);

  log(`found ${deduplicatedNfts.length} unique NFTs from all indexers`, deduplicatedNfts);

  return { nfts: deduplicatedNfts, error };
}
