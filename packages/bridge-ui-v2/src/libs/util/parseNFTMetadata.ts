import axios, { AxiosError } from 'axios';

import { type NFT, type NFTMetadata, TokenType } from '$libs/token';
import { safeParseUrl } from '$libs/util/safeParseUrl';

import { extractIPFSCidFromUrl } from './extractIPFSCidFromUrl';
import { getLogger } from './logger';

const log = getLogger('libs:token:parseNFTMetadata');

export const parseNFTMetadata = async (token: NFT): Promise<NFTMetadata | null> => {
  if (token.type !== TokenType.ERC721 && token.type !== TokenType.ERC1155) throw new Error('Not a NFT');

  log(`fetching metadata for ${token.name} id: ${token.tokenId}`);

  if (!token.uri) throw new Error('No token URI found');

  if (token.uri.includes('{id}')) {
    token.uri = token.uri.replace('{id}', token.tokenId.toString());
  }

  const url = safeParseUrl(token.uri);
  if (!url) throw new Error(`Invalid token URI: ${token.uri}`);

  let json;
  try {
    json = await axios.get(url);
  } catch (err) {
    const error = err as AxiosError;
    log(`error fetching metadata for ${token.name} id: ${token.tokenId}`, error);
    //todo: handle different error scenarios?
    json = await retry(url, token.tokenId);
  }
  if (!json || !json.data) throw new Error(`No metadata found for ${token.name} id: ${token.tokenId}`);

  const metadata = {
    description: json.data.description || '',
    external_url: json.data.external_url || '',
    image: json.data.image || '',
    name: json.data.name || '',
  };

  log(`fetched metadata for ${token.name} id: ${token.tokenId}`, metadata);
  return metadata;
};

const retry = async (url: string, tokenId: number) => {
  const { cid, remainder } = extractIPFSCidFromUrl(url);
  let gateway;
  if (cid && !remainder) {
    gateway = `https://ipfs.io/ipfs/${cid}`;
  } else if (cid && remainder === tokenId.toString()) {
    gateway = `https://ipfs.io/ipfs/${cid}/${remainder}.json`;
  } else {
    log(`no valid CID found in ${url}`);
    return null;
  }

  try {
    log(`retrying with ${gateway}`);
    return await axios.get(gateway);
  } catch (error) {
    log('retrying failed', error);
    return null;
  }
};
