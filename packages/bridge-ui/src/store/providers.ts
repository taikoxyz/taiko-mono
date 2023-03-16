import type { ethers } from 'ethers';
import { writable } from 'svelte/store';

export const providers = writable(
  new Map<number, ethers.providers.JsonRpcProvider>(),
);
