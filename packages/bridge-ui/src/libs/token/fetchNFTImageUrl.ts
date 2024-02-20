import { get } from 'svelte/store';

import { destNetwork } from '$components/Bridge/state';
import { fetchNFTMetadata } from '$libs/token/fetchNFTMetadata';
import { getLogger } from '$libs/util/logger';
import { resolveIPFSUri } from '$libs/util/resolveIPFSUri';
import { metadataCache } from '$stores/metadata';
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

    token.metadata = {
      ...metadata,
      image: imageUrl,
    };

    if (!tokenInfo || !tokenInfo.canonical?.address) return token;

    // check cache for existing metadata
    const cache = get(metadataCache);
    if (cache.has(tokenInfo.canonical?.address)) {
      log('found cached metadata for', tokenInfo.canonical?.address, token.metadata);
      // Update cache
      metadataCache.update((cache) => {
        const key = tokenInfo.canonical?.address;
        if (key && token.metadata) {
          log('updating cache for', key, token.metadata);
          cache.set(key, token.metadata);
        }
        return cache;
      });
    }

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
