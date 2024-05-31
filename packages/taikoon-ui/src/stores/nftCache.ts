import { writable } from 'svelte/store';

// tokenId => fetchedIpfsData
export const nftCache = writable<Record<number, string>>({});

export type INftCache = typeof nftCache;
