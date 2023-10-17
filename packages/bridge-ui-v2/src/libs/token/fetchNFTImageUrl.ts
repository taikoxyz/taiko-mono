import { parseNFTMetadata } from '$libs/util/parseNFTMetadata';
import { safeParseUrl } from '$libs/util/safeParseUrl';

import type { NFT, NFTMetadata } from './types';

const PLACEHOLDER_IMAGE_URL = '/chains/taiko.svg';

export const fetchNFTImageUrl = async (token: NFT) => {
  try {
    let metadata: NFTMetadata | null;
    if (!token.metadata) {
      metadata = await parseNFTMetadata(token);
    } else {
      metadata = token.metadata;
    }
    if (!metadata?.image || metadata?.image === '') return PLACEHOLDER_IMAGE_URL;
    return safeParseUrl(metadata?.image);
  } catch (error) {
    return PLACEHOLDER_IMAGE_URL;
  }
};
