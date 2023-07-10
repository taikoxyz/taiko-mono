import type { GetNetworkResult } from '@wagmi/core';
import { writable } from 'svelte/store';

export const srcChain = writable<GetNetworkResult['chain']>();

export const destChain = writable<GetNetworkResult['chain']>();
