import type { GetNetworkResult } from '@wagmi/core';
import { writable } from 'svelte/store';

import { chains } from '$libs/chain';

export const srcChain = writable<GetNetworkResult['chain']>();

export const destChain = writable<GetNetworkResult['chain']>();

srcChain.subscribe((newChain) => {
  if (newChain && chains.length === 2) {
    // If there are only two chains, the destination chain will be the other one
    const otherChain = chains.find((chain) => chain.id !== newChain.id);
    destChain.set(otherChain);
  }
});
