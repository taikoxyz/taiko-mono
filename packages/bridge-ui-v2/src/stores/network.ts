import { type GetNetworkResult, switchNetwork } from '@wagmi/core';
import { writable } from 'svelte/store';

export const srcChain = writable<GetNetworkResult['chain']>();

export const destChain = writable<GetNetworkResult['chain']>();

// Changing source chain from UI should trigger network switch
srcChain.subscribe((chain) => {
  if (!chain) return;
  switchNetwork({ chainId: chain.id });
});
