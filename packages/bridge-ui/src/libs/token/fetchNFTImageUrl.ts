import { get } from 'svelte/store';

import { destNetwork } from '$components/Bridge/state';
import { ipfsConfig } from '$config';
import { fetchNFTMetadata } from '$libs/token/fetchNFTMetadata';
import { decodeBase64ToJson } from '$libs/util/decodeBase64ToJson';
import { fetchFromIPFSGateways, toIPFSPath } from '$libs/util/ipfsGateways';
import { getLogger } from '$libs/util/logger';
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
    // Any URL a gateway serves, not only an `ipfs://` one. The image inside a metadata document
    // usually points at the same project-owned gateway the document itself did, so a gateway
    // that has stopped answering takes the image down with it even once the document has been
    // recovered from elsewhere - the content is the same either way, addressed by hash.
    if (toIPFSPath(url) !== null) {
      return fetchFromIPFSGateways(
        url,
        async (candidate) => {
          // Loading the image is the test, so a gateway that answers but does not serve this
          // content hands the next one its turn rather than ending the search
          if (!(await testImageLoad(candidate))) throw new Error(`Gateway did not serve the image: ${candidate}`);
          return candidate;
        },
        { attemptTimeout: ipfsConfig.imageLoadTimeout, budget: ipfsConfig.imageOverallTimeout },
      );
    } else if (url.startsWith('data:image/svg+xml;base64,')) {
      const base64 = url.replace('data:image/svg+xml;base64,', '');
      const decodedImage = decodeBase64ToJson(base64);
      return decodedImage;
    }
  }
  throw new Error(`No image found for ${url}`);
};

/**
 * @dev Whether the browser can load `url` as an image, within a bounded wait.
 *
 *      A stalled gateway fires neither `onload` nor `onerror`, so without the timeout this never
 *      settles and holds up everything waiting on it. Clearing `src` on the way out lets the
 *      browser drop the request rather than leaving it in flight behind an answer nobody reads.
 *
 * @param url The image to load
 * @return loaded_ Whether it loaded in time
 */
const testImageLoad = (url: string): Promise<boolean> => {
  return new Promise((resolve) => {
    const img = new Image();

    const settle = (loaded: boolean) => {
      clearTimeout(timer);
      img.onload = null;
      img.onerror = null;
      if (!loaded) img.src = '';
      resolve(loaded);
    };

    const timer = setTimeout(() => settle(false), ipfsConfig.imageLoadTimeout);

    img.onload = () => settle(true);
    img.onerror = () => settle(false);
    img.src = url;
  });
};
