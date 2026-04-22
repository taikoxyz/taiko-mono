import { get, writable } from 'svelte/store';
import type { Address } from 'viem';

import type { NFTMetadata } from '$libs/token';

export type NFTCacheIdentifier = {
  address: Address;
  id: number;
};

function createCacheKey(identifier: NFTCacheIdentifier): string {
  return `${identifier.address}-${identifier.id.toString()}`;
}

export const metadataCache = writable<Map<string, NFTMetadata>>(new Map());

export function addMetadataToCache(identifier: NFTCacheIdentifier, metadata: NFTMetadata): void {
  metadataCache.update((cache) => {
    const key = createCacheKey(identifier);
    cache.set(key, metadata);
    return cache;
  });
}

export function getMetadataFromCache(identifier: NFTCacheIdentifier): NFTMetadata | undefined {
  const cache = get(metadataCache);
  const key = createCacheKey(identifier);
  return cache.get(key);
}

export function isMetadataCached(identifier: NFTCacheIdentifier): boolean {
  let exists = false;
  metadataCache.subscribe((cache) => {
    const key = createCacheKey(identifier);
    exists = cache.has(key);
  })();
  return exists;
}
