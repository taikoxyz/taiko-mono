import { get, type Writable, writable } from 'svelte/store';
import type { Hash } from 'viem';

import type { GetProofReceiptResponse } from '$libs/bridge';

type CachedProofReceipt = Record<Hash, GetProofReceiptResponse>;

function createCachedProofReceiptStore() {
  const { subscribe, set, update }: Writable<CachedProofReceipt | null> = writable(null);

  return {
    subscribe,
    updateCache: (hash: Hash, response: GetProofReceiptResponse) =>
      update((currentCache) => {
        if (currentCache === null) {
          currentCache = {};
        }
        if (!currentCache[hash] || currentCache[hash] !== response) {
          currentCache[hash] = response;
        }
        return currentCache;
      }),
    removeCache: (hash: Hash) =>
      update((currentCache) => {
        if (currentCache && currentCache[hash]) {
          delete currentCache[hash];
        }
        return currentCache;
      }),
    clearCache: () => set(null),
    getCache: (hash: Hash): GetProofReceiptResponse | undefined => {
      const currentCache = get({ subscribe });
      return currentCache ? currentCache[hash] : undefined;
    },
  };
}

export const proofReceiptForMsgHash = createCachedProofReceiptStore();
