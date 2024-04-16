import axios, { AxiosError, type AxiosRequestConfig } from 'axios';
import { get } from 'svelte/store';

import { destNetwork } from '$components/Bridge/state';
import { ipfsConfig } from '$config';
import { FetchMetadataError, NoMetadataFoundError, WrongChainError } from '$libs/error';
import { decodeBase64ToJson } from '$libs/util/decodeBase64ToJson';
import { getLogger } from '$libs/util/logger';
import { resolveIPFSUri } from '$libs/util/resolveIPFSUri';
import { getMetadataFromCache, isMetadataCached, metadataCache } from '$stores/metadata';
import { connectedSourceChain } from '$stores/network';

import { getTokenAddresses } from './getTokenAddresses';
import { getTokenWithInfoFromAddress } from './getTokenWithInfoFromAddress';
import type { NFT, NFTMetadata } from './types';

const axiosConfig: AxiosRequestConfig = {
  timeout: ipfsConfig.gatewayTimeout,
};

const log = getLogger('libs:token:fetchNFTMetadata');

export async function fetchNFTMetadata(token: NFT): Promise<NFTMetadata | null> {
  let uri = token?.uri;
  const srcChainId = get(connectedSourceChain)?.id;
  const destChainId = get(destNetwork)?.id;
  if (!srcChainId || !destChainId) return null;

  const tokenInfo = await getTokenAddresses({ token, srcChainId, destChainId });

  if (!tokenInfo || !tokenInfo.canonical?.address) return null;

  // check cache for metadata
  if (isMetadataCached({ address: tokenInfo.canonical?.address, id: token.tokenId })) {
    log('found cached metadata for', tokenInfo.canonical?.address, token.metadata);
    // Update cache
    const data = getMetadataFromCache({ address: tokenInfo.canonical?.address, id: token.tokenId });
    if (data) return data;
  }
  log('no cached metadata found', token);
  if (uri && uri.startsWith('ethereum:')) {
    // we have an EIP-681 address
    // https://eips.ethereum.org/EIPS/eip-681
    // TODO: implement EIP-681, for now we treat it as invalid URI
    uri = '';
  } else if (uri && uri.startsWith('data:application/json;base64')) {
    // we have a base64 encoded json
    const base64 = uri.replace('data:application/json;base64,', '');
    const decodedData = decodeBase64ToJson(base64);
    const metadata: NFTMetadata = {
      ...decodedData,
      image: decodedData.image,
      name: decodedData.name,
      description: decodedData.description,
      external_url: decodedData.external_url,
    };
    if (decodedData.image) {
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
  }
  if (!uri || uri === '') {
    const crossChainMetadata = await crossChainFetchNFTMetadata(token);
    if (crossChainMetadata && crossChainMetadata.image) {
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
  if (!uri) throw new FetchMetadataError('No uri found');

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
    throw new NoMetadataFoundError('No image in metadata');
  } catch (error) {
    throw new FetchMetadataError(`Failed to fetch NFT metadata: ${(error as AxiosError).message}`);
  }
}

const crossChainFetchNFTMetadata = async (token: NFT): Promise<NFTMetadata | null> => {
  try {
    log(`Trying crosschainFetch for ${token.name} id: ${token.tokenId}`);

    const srcChainId = get(connectedSourceChain)?.id;
    const destChainId = get(destNetwork)?.id;

    if (!srcChainId || !destChainId || srcChainId === destChainId) throw new WrongChainError();

    const tokenInfo = await getTokenAddresses({ token, srcChainId, destChainId });

    if (tokenInfo && tokenInfo.canonical && tokenInfo.canonical.address && tokenInfo.canonical.chainId) {
      const canonicalChainID = tokenInfo.canonical.chainId;
      const canonicalAddress = tokenInfo.canonical.address;
      log(`Fetching metadata for ${token.name} from chain ${canonicalChainID} at address ${canonicalAddress}`);

      // this "builds" the canonical token and calls the fetchNFTMetadata function again with it
      const canonicalToken = (await getTokenWithInfoFromAddress({
        contractAddress: canonicalAddress,
        srcChainId: canonicalChainID,
        tokenId: token.tokenId,
        type: token.type,
      })) as NFT;
      canonicalToken.addresses = { ...token.addresses, [canonicalChainID]: canonicalAddress };

      if (!canonicalToken.uri) throw new FetchMetadataError('No uri found');
      return canonicalToken.metadata || null;
    }
    throw new NoMetadataFoundError('No crosschain metadata found');
  } catch (error) {
    log('Error fetching cross chain metadata', error);
    throw new FetchMetadataError('No crosschain metadata found', { cause: error });
  }
};
