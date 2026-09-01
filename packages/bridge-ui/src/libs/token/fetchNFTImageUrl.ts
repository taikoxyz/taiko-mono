import { get } from 'svelte/store';

import { destNetwork } from '$components/Bridge/state';
import { fetchNFTMetadata } from '$libs/token/fetchNFTMetadata';
import { decodeBase64ToJson } from '$libs/util/decodeBase64ToJson';
import { getLogger } from '$libs/util/logger';
import { resolveIPFSUri } from '$libs/util/resolveIPFSUri';
import { addMetadataToCache } from '$stores/metadata';
import { connectedSourceChain } from '$stores/network';

import { getTokenAddresses } from './getTokenAddresses';
import type { NFT, NFTMetadata } from './types';

const log = getLogger('libs:token:fetchNFTImageUrl');

export const fetchNFTImageUrl = async (token: NFT): Promise<NFT> => {
  const srcChainId = get(connectedSourceChain)?.id;
  const destChainId = get(destNetwork)?.id;
  if (!srcChainId || !destChainId) return token;

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

    const imageUrlPromise = fetchImageUrl(metadata.image);
    const tokenInfoPromise = getTokenAddresses({ token, srcChainId, destChainId });

    const [imageUrl, tokenInfo] = await Promise.all([imageUrlPromise, tokenInfoPromise]);

    // Bound to a local so what reaches the cache is visibly this object and not a field
    // that might since have become undefined - a reading five separate reviews have taken
    const resolvedMetadata = {
      ...metadata,
      image: imageUrl,
    };
    token.metadata = resolvedMetadata;

    if (!tokenInfo || !tokenInfo.canonical?.address) return token;

    // Store the resolved metadata so the next lookup hits the cache
    addMetadataToCache({ address: tokenInfo.canonical.address, id: token.tokenId }, resolvedMetadata);

    return token;
  } catch (error) {
    log(`Error fetching image for ${token.name} id: ${token.tokenId}`, error);
    return token;
  }
};

const fetchImageUrl = async (url: string): Promise<string> => {
  const imageLoaded = await testImageLoad(url);

  if (imageLoaded) {
    return url;
  } else {
    log('fetchImageUrl failed to load image');
    if (url.startsWith('ipfs://')) {
      const newUrl = await resolveIPFSUri(url);
      if (newUrl) {
        const gatewayImageLoaded = await testImageLoad(newUrl);
        if (gatewayImageLoaded) {
          return newUrl;
        }
      }
    } else if (url.startsWith('data:image/svg+xml;base64,')) {
      const base64 = url.replace('data:image/svg+xml;base64,', '');
      const decodedImage = decodeBase64ToJson(base64);
      return decodedImage;
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
