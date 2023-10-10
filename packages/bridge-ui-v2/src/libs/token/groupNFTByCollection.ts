import type { NFT } from './types';

export function groupNFTByCollection(nfts: NFT[]): Record<string, NFT[]> {
  const grouped: Record<string, NFT[]> = {};
  nfts.forEach((nft) => {
    const addressKey = Object.values(nft.addresses).join('-');
    if (!grouped[addressKey]) {
      grouped[addressKey] = [];
    }
    grouped[addressKey].push(nft);
  });
  return grouped;
}
