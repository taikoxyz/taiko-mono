import type { Address } from 'viem';

import { eventIndexerApiServices } from '$libs/eventIndexer/initEventIndexer';
import { type NFT, TokenType } from '$libs/token';
import { checkOwnershipOfNFTs } from '$libs/token/checkOwnership';
import { fetchNFTImageUrl } from '$libs/token/fetchNFTImageUrl';
import { getTokenWithInfoFromAddress } from '$libs/token/getTokenWithInfoFromAddress';
import { getLogger } from '$libs/util/logger';

const log = getLogger('bridge:fetchNFTs');

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

export async function fetchNFTs(
  userAddress: Address,
  srcChainId: number,
): Promise<{ nfts: NFT[]; error: Error | null }> {
  let error: Error | null = null;

  // Fetch from all indexers
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
    error = e as Error;
  }

  // Deduplicate based on address and chainID
  const deduplicatedNfts = deduplicateNFTs(nftArrays);

  // Fetch image for each NFT
  const promises = Promise.all(
    deduplicatedNfts.map(async (nft) => {
      const nftWithImage = await fetchNFTImageUrl(nft);
      return nftWithImage;
    }),
  );
  const nftsWithImage = await promises;

  // Double check the ownership
  const ownsAllNfts = await checkOwnershipOfNFTs(nftsWithImage, userAddress, srcChainId);
  log(`user ${userAddress} owns all NFTs:`, ownsAllNfts);
  // filter out the NFTs that the user doesn't own
  const filteredNfts = nftsWithImage.filter((nft) => {
    const isOwned = ownsAllNfts.successfulOwnershipChecks.find((result) => result.tokenId === nft.tokenId);
    return isOwned;
  });

  if (filteredNfts.length !== nftsWithImage.length) {
    //TODO: handle this case differently? maybe show a warning to the user?
    log(`found ${nftsWithImage.length - filteredNfts.length} tokens that the user doesn't own`);
  }

  log(`found ${filteredNfts.length} unique NFTs from all indexers`, filteredNfts);

  return { nfts: filteredNfts, error };
}
