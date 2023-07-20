import type { GetNetworkResult } from '@wagmi/core';
import { writable } from 'svelte/store';

export type Network = GetNetworkResult['chain'];

export const network = writable<Network>();
