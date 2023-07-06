import type { GetNetworkResult } from '@wagmi/core';
import { writable } from 'svelte/store';

export const network = writable<GetNetworkResult>();
