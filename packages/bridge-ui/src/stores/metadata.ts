import { writable } from 'svelte/store';
import type { Address } from 'viem';

import type { NFTMetadata } from '$libs/token';

export const metadataCache = writable(new Map<Address, NFTMetadata>());
