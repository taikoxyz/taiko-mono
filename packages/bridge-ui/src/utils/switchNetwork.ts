import { switchNetwork as wagmiSwitchNetwork } from '@wagmi/core';
import { get } from 'svelte/store';

import { srcChain } from '../store/chain';

export async function switchNetwork(chainId: number) {
  const prevChainId = get(srcChain).id;

  if (prevChainId === chainId) return;

  await wagmiSwitchNetwork({ chainId });

  return new Promise<void>((resolve) => {
    const waitForNetworkChange = () => {
      if (get(srcChain).id !== prevChainId) {
        resolve();
      } else {
        setTimeout(waitForNetworkChange, 500);
      }
    };

    waitForNetworkChange();
  });
}
