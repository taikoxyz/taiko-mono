import axios from 'axios';

// import { checkForAdblocker } from '$libs/util/checkForAdblock';
import { extractIPFSCidFromUrl } from '$libs/util/extractIPFSCidFromUrl';
import { fetchNFTMetadata } from '$libs/util/fetchNFTMetadata';
import { getFileExtension } from '$libs/util/getFileExtension';
import { getLogger } from '$libs/util/logger';
import { safeParseUrl } from '$libs/util/safeParseUrl';

import type { NFT } from './types';

const log = getLogger('libs:token:fetchNFTImageUrl');

const retryRequest = async (url: string | null): Promise<string> => {
  if (url === null) {
    throw new Error('No URL provided for retry');
  }

  try {
    await axios.get(url);
    return url;
  } catch (error) {
    log('retrying failed', error);
    throw new Error(`No image found for ${url}`);
  }
};

const useGateway = (url: string, tokenId: number): string | null => {
  const { cid } = extractIPFSCidFromUrl(url);
  const extension = getFileExtension(url);
  if (tokenId !== undefined && tokenId !== null && cid) {
    return `https://ipfs.io/ipfs/${cid}/${tokenId}.${extension}`;
  } else {
    log(`No valid CID found in ${url}`);
    return null;
  }
};

const fetchImageUrl = async (url: string, tokenId: number): Promise<string> => {
  try {
    await axios.get(url);
    return url;
  } catch {
    const newUrl = useGateway(url, tokenId);
    if (newUrl) {
      return await retryRequest(newUrl);
    }
    throw new Error(`No image found for ${url}`);
  }
};

// Main function to fetch NFT image URL
export const fetchNFTImageUrl = async (token: NFT): Promise<NFT> => {
  try {
    const metadata = token.metadata || (await fetchNFTMetadata(token)); // Assume fetchNFTMetadata is imported
    if (!metadata?.image) throw new Error('No image found');

    const url = safeParseUrl(metadata.image); // Assume safeParseUrl is defined elsewhere
    if (!url) throw new Error(`Invalid image URL: ${metadata.image}`);

    const imageUrl = await fetchImageUrl(url, token.tokenId);
    token.metadata = {
      ...metadata,
      image: imageUrl,
    };
    return token;
  } catch (error) {
    log(`Error fetching image for ${token.name} id: ${token.tokenId}`, error);
    return token; // Returning the original token if any error occurs
  }
};
