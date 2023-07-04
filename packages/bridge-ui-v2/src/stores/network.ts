import { writable } from 'svelte/store';
import type { GetNetworkResult } from 'wagmi/actions';

export const network = writable<GetNetworkResult>();
