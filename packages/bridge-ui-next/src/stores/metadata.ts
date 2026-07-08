// Ported from stores/metadata.ts.
//
// The original was a svelte `writable<Map<string, NFTMetadata>>`. Non-React lib
// code (fetchNFTMetadata.ts, fetchNFTImageUrl.ts) uses three helpers plus the raw
// `metadataCache.update(fn)` svelte contract. Re-implemented as a Zustand VANILLA
// store. We expose an `update(fn)` method matching svelte's writable.update so the
// existing `metadataCache.update((cache) => { ... return cache; })` calls work
// unchanged. The helper functions (addMetadataToCache / getMetadataFromCache /
// isMetadataCached) keep their exact signatures.
import { createValueStore } from "@/stores/createValueStore";
import type { Address } from "viem";

import type { NFTMetadata } from "$libs/token";

export type NFTCacheIdentifier = {
  address: Address;
  id: number;
};

function createCacheKey(identifier: NFTCacheIdentifier): string {
  return `${identifier.address}-${identifier.id.toString()}`;
}

const cacheStore = createValueStore<Map<string, NFTMetadata>>(() => new Map());

/**
 * Svelte-`writable`-compatible facade around the vanilla zustand store so callers
 * can keep using `metadataCache.update(fn)` and `get(metadataCache)` semantics.
 * `update` returns a NEW Map reference (the svelte version reassigned via update)
 * so React subscribers re-render.
 */
export const metadataCache = {
  getState: () => cacheStore.getState(),
  setState: (next: Map<string, NFTMetadata>) => cacheStore.setState(next, true),
  subscribe: cacheStore.subscribe,
  update: (
    updater: (cache: Map<string, NFTMetadata>) => Map<string, NFTMetadata>,
  ) => {
    const current = new Map(cacheStore.getState());
    const next = updater(current);
    cacheStore.setState(next, true);
  },
};

export function addMetadataToCache(
  identifier: NFTCacheIdentifier,
  metadata: NFTMetadata,
): void {
  metadataCache.update((cache) => {
    const key = createCacheKey(identifier);
    cache.set(key, metadata);
    return cache;
  });
}

export function getMetadataFromCache(
  identifier: NFTCacheIdentifier,
): NFTMetadata | undefined {
  const cache = cacheStore.getState();
  const key = createCacheKey(identifier);
  return cache.get(key);
}

export function isMetadataCached(identifier: NFTCacheIdentifier): boolean {
  const cache = cacheStore.getState();
  const key = createCacheKey(identifier);
  return cache.has(key);
}
