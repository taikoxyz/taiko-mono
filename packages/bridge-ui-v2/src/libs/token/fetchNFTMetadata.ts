import axios, { AxiosError, type AxiosRequestConfig } from 'axios';
import { get } from 'svelte/store';

import { destNetwork } from '$components/Bridge/state';
import { NoMetadataFoundError, WrongChainError } from '$libs/error';
import { getLogger } from '$libs/util/logger';
import { resolveIPFSUri } from '$libs/util/resolveIPFSUri';
import { metadataCache } from '$stores/metadata';
import { network } from '$stores/network';

import { getTokenAddresses } from './getTokenAddresses';
import { getTokenWithInfoFromAddress } from './getTokenWithInfoFromAddress';
import type { NFT, NFTMetadata } from './types';

const REQUEST_TIMEOUT_IN_MS = 200;

const axiosConfig: AxiosRequestConfig = {
  timeout: REQUEST_TIMEOUT_IN_MS,
};

const log = getLogger('libs:token:fetchNFTMetadata');

export async function fetchNFTMetadata(token: NFT): Promise<NFTMetadata | null> {
  let uri = token?.uri;
  const srcChainId = get(network)?.id;
  const destChainId = get(destNetwork)?.id;
  if (!srcChainId || !destChainId) return null;

  const tokenInfo = await getTokenAddresses({ token, srcChainId, destChainId });
  if (!tokenInfo || !tokenInfo.canonical?.address) return null;

  // check cache for metadata
  const cache = get(metadataCache);
  if (cache.has(tokenInfo.canonical?.address)) {
    const cachedMetadata = cache.get(tokenInfo.canonical?.address);
    if (cachedMetadata) {
      log('Found cached metadata for', tokenInfo.canonical?.address, cachedMetadata);
      return cachedMetadata;
    }
  }
  log('no cached metadata found', token);
  if (!uri) {
    const crossChainMetadata = await crossChainFetchNFTMetadata(token);
    if (crossChainMetadata) {
      // Update cache
      metadataCache.update((cache) => {
        const key = tokenInfo.canonical?.address;
        if (key) {
          cache.set(key, crossChainMetadata);
        }
        return cache;
      });
      return crossChainMetadata;
    }
  }
  if (!uri) throw new Error('No uri found');

  if (uri.startsWith('ipfs:')) {
    uri = await resolveIPFSUri(uri);
  }

  try {
    const response = await axios.get<NFTMetadata>(uri, axiosConfig);
    const metadata = response.data;

    if (metadata.image) {
      // Update cache
      metadataCache.update((cache) => {
        const key = tokenInfo.canonical?.address;
        if (key) {
          cache.set(key, metadata);
        }
        return cache;
      });
      return metadata;
    }
    throw new Error('No image in metadata');
  } catch (error) {
    throw new Error(`Failed to fetch NFT metadata: ${(error as AxiosError).message}`);
  }
}

const crossChainFetchNFTMetadata = async (token: NFT): Promise<NFTMetadata | null> => {
  try {
    log(`Trying crosschainFetch for ${token.name} id: ${token.tokenId}`);

    const srcChainId = get(network)?.id;
    const destChainId = get(destNetwork)?.id;

    if (!srcChainId || !destChainId || srcChainId === destChainId) throw new WrongChainError();

    const tokenInfo = await getTokenAddresses({ token, srcChainId, destChainId });

    if (tokenInfo && tokenInfo.canonical && tokenInfo.canonical.address && tokenInfo.canonical.chainId) {
      const canonicalChainID = tokenInfo.canonical.chainId;
      const canonicalAddress = tokenInfo.canonical.address;

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
    }
    throw new NoMetadataFoundError('No crosschain metadata found');
  } catch (error) {
    log('Error fetching cross chain metadata', error);
    throw new NoMetadataFoundError('No crosschain metadata found');
  }
};
