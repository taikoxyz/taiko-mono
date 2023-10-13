import { parseNFTMetadata } from '$libs/util/parseNFTMetadata';
import { safeParseUrl } from '$libs/util/safeParseUrl';

import type { NFT } from './types';

const PLACEHOLDER_IMAGE_URL = '/chains/taiko.svg';

export const fetchNFTImageUrl = async (token: NFT) => {
  try {
    const metadata = await parseNFTMetadata(token);
    if (!metadata?.image || metadata?.image === '') return PLACEHOLDER_IMAGE_URL;
    return safeParseUrl(metadata?.image);
  } catch (error) {
    return PLACEHOLDER_IMAGE_URL;
  }
};
