import { writable } from 'svelte/store';

import type { NFTMetadata } from '$libs/token';

export const metadataCache = writable(new Map<string, NFTMetadata>());
