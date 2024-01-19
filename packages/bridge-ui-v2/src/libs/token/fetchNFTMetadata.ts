import axios, { AxiosError, type AxiosRequestConfig } from 'axios';
import { get } from 'svelte/store';
import type { Address } from 'viem';

import { destNetwork } from '$components/Bridge/state';
import { getLogger } from '$libs/util/logger';
import { resolveIPFSUri } from '$libs/util/resolveIPFSUri';
import { getCanonicalTokenInfo } from '$stores/canonical';
import { metadataCache } from '$stores/metadata';
import { network } from '$stores/network';

import { getCanonicalInfoForToken } from './getCanonicalInfoForToken';
import { getTokenWithInfoFromAddress } from './getTokenWithInfoFromAddress';
import type { NFT, NFTMetadata } from './types';

const REQUEST_TIMEOUT_IN_MS = 200;

const axiosConfig: AxiosRequestConfig = {
  timeout: REQUEST_TIMEOUT_IN_MS,
};

const log = getLogger('libs:token:fetchNFTMetadata');

export async function fetchNFTMetadata(token: NFT): Promise<NFTMetadata | null> {
  let uri = token?.uri;
  if (!uri) {
    const crossChainMetadata = await crossChainFetchNFTMetadata(token);
    if (crossChainMetadata) return crossChainMetadata;
  }
  if (!uri) throw new Error('No uri found');

  const cache = get(metadataCache);
  if (cache.has(uri)) return cache.get(uri) || null;

  if (uri.startsWith('ipfs:')) {
    uri = await resolveIPFSUri(uri);
  }

  try {
    const response = await axios.get<NFTMetadata>(uri, axiosConfig);
    const metadata = response.data;

    if (metadata.image) {
      cacheMetadata(uri, metadata);
      return metadata;
    }
    throw new Error('No image in metadata');
  } catch (error) {
    throw new Error(`Failed to fetch NFT metadata: ${(error as AxiosError).message}`);
  }
}

function cacheMetadata(uri: string, metadata: NFTMetadata) {
  metadataCache.update((cache) => {
    cache.set(uri, metadata);
    return cache;
  });
}

const crossChainFetchNFTMetadata = async (token: NFT): Promise<NFTMetadata | null> => {
  try {
    log(`Trying crosschainFetch for ${token.name} id: ${token.tokenId}`);

    const srcChainId = get(network)?.id;
    const destChainId = get(destNetwork)?.id;
    if (!srcChainId || !destChainId) throw new Error('No srcChainId found');

    // any tokenAddress will do
    const tokenAddress = Object.values(token.addresses)[0];

    let canonicalAddress: Address;
    let canonicalChainID: number;

    if (getCanonicalTokenInfo(tokenAddress) && getCanonicalTokenInfo(tokenAddress).isCanonical) {
      canonicalAddress = tokenAddress;
      canonicalChainID = getCanonicalTokenInfo(tokenAddress).chainId;
    } else {
      const canonicalInfo = await getCanonicalInfoForToken({ token, srcChainId, destChainId });
      if (!canonicalInfo) throw new Error('No cross chain info found');
      canonicalAddress = canonicalInfo.address;
      canonicalChainID = canonicalInfo.chainId;
    }

    log(`Fetching metadata for ${token.name} from chain ${canonicalChainID} at address ${canonicalAddress}`);

    const cToken = (await getTokenWithInfoFromAddress({
      contractAddress: canonicalAddress,
      srcChainId: canonicalChainID,
      tokenId: token.tokenId,
      type: token.type,
    })) as NFT;
    cToken.addresses = { ...token.addresses, [canonicalChainID]: canonicalAddress };

    if (!cToken.uri) throw new Error('No uri found');
    return cToken.metadata || null;
  } catch (error) {
    log('Error fetching cross chain metadata');
    console.error(error);
    return null;
  }
};
