import { get } from 'svelte/store';

import { nftCache } from '$stores/nftCache';

import Token from '../token';
import httpGet from './httpGet';
//import get from './get';

export interface ITokenMetadata {
  name: string;
  description: string;
  image: string;
}
export default async function getMetadata(tokenId: number): Promise<ITokenMetadata> {
  const tokenURI = await Token.tokenURI(tokenId);
  // const metadata = (await get(tokenURI, true)) as ITokenMetadata;

  const cachedIds = get(nftCache);
  const cached = cachedIds[tokenId];
  let metadata;
  if (!cached) {
    metadata = (await httpGet(tokenURI, true)) as ITokenMetadata;
    nftCache.set({
      ...cachedIds,
      [tokenId]: JSON.stringify(metadata),
    });
  } else {
    metadata = JSON.parse(cached);
  }

  return metadata;
}
