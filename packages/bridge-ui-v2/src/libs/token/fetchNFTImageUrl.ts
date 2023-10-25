import axios, { AxiosError, type AxiosResponse } from 'axios';

import { checkForAdblocker } from '$libs/util/checkForAdblock';
import { extractIPFSCidFromUrl } from '$libs/util/extractIPFSCidFromUrl';
import { fetchNFTMetadata } from '$libs/util/fetchNFTMetadata';
import { getFileExtension } from '$libs/util/getFileExtension';
import { getLogger } from '$libs/util/logger';
import { safeParseUrl } from '$libs/util/safeParseUrl';

import type { NFT, NFTMetadata } from './types';

const log = getLogger('libs:token:fetchNFTImageUrl');

// TODO: very similar to fetchNFTMetadata, can we combine them?
export const fetchNFTImageUrl = async (token: NFT): Promise<NFT> => {
  try {
    let metadata: NFTMetadata | null;
    if (!token.metadata) {
      metadata = await fetchNFTMetadata(token);
    } else {
      metadata = token.metadata;
    }
    if (!metadata?.image || metadata?.image === '') throw new Error('No image found');
    else {
      const url = safeParseUrl(metadata.image);
      if (!url) throw new Error(`Invalid image URL: ${metadata.image}`);

      let image;
      try {
        image = await axios.get(url);
      } catch (err) {
        const error = err as AxiosError;
        log(`error fetching image for ${token.name} id: ${token.tokenId}`, error);
        //todo: handle different error scenarios?
        image = await retry(url, token.tokenId);
      }
      if (!image) {
        const isBlocked = await checkForAdblocker(url);
        if (isBlocked) {
          log(`The resource at ${url} is blocked by an adblocker`);
          image = await retry(url, token.tokenId);
        } else {
          throw new Error(`No image found for ${token.name} id: ${token.tokenId}`);
        }
      }

      if (!image || image instanceof Error) {
        // Handle errorx
        throw new Error(`No image found for ${token.name} id: ${token.tokenId}`);
      }
      if (token.metadata) {
        token.metadata.image = url;
      } else {
        token.metadata = {
          description: '',
          external_url: '',
          image: url,
          name: '',
        };
      }
    }
    return token;
  } catch (error) {
    return token;
  }
};

// TODO: we could retry several times with different gateways
const retry = async (url: string, tokenId: number): Promise<AxiosResponse | Error> => {
  let newUrl;
  tokenId !== undefined && tokenId !== null ? (newUrl = useGateway(url, tokenId)) : (newUrl = useGateway(url, tokenId));
  if (newUrl) {
    const result = await retryRequest(newUrl);
    if (result instanceof Error) {
      return result;
    }
    return result;
  }
  return new Error(`No image found for ${url}`);
};

const retryRequest = async (newUrl: string): Promise<AxiosResponse | Error> => {
  try {
    log(`retrying with ${newUrl}`);
    return await axios.get(newUrl);
  } catch (error) {
    log('retrying failed', error);
    throw new Error(`No image found for ${newUrl}`);
  }
};

//TODO: make this configurable via the config system?
const useGateway = (url: string, tokenId: number) => {
  const { cid } = extractIPFSCidFromUrl(url);
  const extension = getFileExtension(url);
  let gateway: string;
  if (tokenId !== undefined && tokenId !== null && cid) {
    gateway = `https://ipfs.io/ipfs/${cid}/${tokenId}.${extension}`;
  } else {
    log(`no valid CID found in ${url}`);
    return null;
  }
  return gateway;
};
