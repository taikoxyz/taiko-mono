import { fetchNFTMetadata } from '$libs/token/fetchNFTMetadata';
import { getLogger } from '$libs/util/logger';
import { resolveIPFSUri } from '$libs/util/resolveIPFSUri';

import type { NFT, NFTMetadata } from './types';

const log = getLogger('libs:token:fetchNFTImageUrl');

const fetchImageUrl = async (url: string): Promise<string> => {
  const imageLoaded = await testImageLoad(url);

  if (imageLoaded) {
    return url;
  } else {
    log('fetchImageUrl failed to load image');
    const newUrl = await resolveIPFSUri(url);
    if (newUrl) {
      const gatewayImageLoaded = await testImageLoad(newUrl);
      if (gatewayImageLoaded) {
        return newUrl;
      }
    }
  }
  throw new Error(`No image found for ${url}`);
};

const testImageLoad = (url: string): Promise<boolean> => {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => resolve(true);
    img.onerror = () => resolve(false);
    img.src = url;
  });
};

export const fetchNFTImageUrl = async (token: NFT): Promise<NFT> => {
  try {
    let metadata: NFTMetadata | null = token?.metadata || null;

    if (!token.metadata) {
      const fetchedMetadata = await fetchNFTMetadata(token);
      if (!fetchedMetadata) throw new Error('No cross chain data found');
      token.metadata = fetchedMetadata;
      metadata = fetchedMetadata;
    }
    if (!metadata) throw new Error('No metadata found');
    if (!metadata?.image) throw new Error('No image found');

    const imageUrl = await fetchImageUrl(metadata.image);

    token.metadata = {
      ...metadata,
      image: imageUrl,
    };
    return token;
  } catch (error) {
    log(`Error fetching image for ${token.name} id: ${token.tokenId}`, error);
    return token;
  }
};

// const crossChainFetchNFTMetadata = async (
//   token: NFT,
//   srcChainId: number,
//   destChainId: number,
// ): Promise<NFTMetadata | null> => {
//   try {
//     return await fetchNFTMetadata(token?.uri);
//   } catch (error) {
//     log(`Trying crosschainFetch`);

//     const tokenAddress = token.addresses[srcChainId];
//     let canonicalAddress: Address;
//     let canonicalChainID: number;

//     if (getCanonicalTokenInfo(tokenAddress) && getCanonicalTokenInfo(tokenAddress).isCanonical) {
//       canonicalAddress = tokenAddress;
//       canonicalChainID = srcChainId;
//     } else {
//       const canonicalInfo = await getCanonicalInfoForToken({ token, srcChainId, destChainId });
//       if (!canonicalInfo) throw new Error('No cross chain info found');
//       canonicalAddress = canonicalInfo.address;
//       canonicalChainID = canonicalInfo.chainId;
//     }

//     log(`Fetching metadata for ${token.name} from chain ${canonicalChainID} at address ${canonicalAddress}`);

//     const cToken = (await getTokenWithInfoFromAddress({
//       contractAddress: canonicalAddress,
//       srcChainId: canonicalChainID,
//       tokenId: token.tokenId,
//       type: token.type,
//     })) as NFT;
//     cToken.addresses = { ...token.addresses, [canonicalChainID]: canonicalAddress };
//     return await fetchNFTMetadata(token?.uri);
//   }
// };
