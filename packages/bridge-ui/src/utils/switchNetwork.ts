import { switchNetwork as wagmiSwitchNetwork } from '@wagmi/core';
import { get } from 'svelte/store';

import { srcChain } from '../store/chain';

export async function switchNetwork(chainId: number) {
  const prevChainId = get(srcChain)?.id;

  if (prevChainId === chainId) return;

  await wagmiSwitchNetwork({ chainId });

  // What are we doing here? we have a watcher waiting for network changes.
  // When this happens this watcher is called and takes care of setting
  // the signer and chains in the store. We are actually waiting here
  // for these stores to change due to some race conditions in the UI.
  // There will be a better design around this in alpha-4: fewer stores
  // and also "$:"" tags for reactivity.
  return new Promise<void>((resolve) => {
    const waitForNetworkChange = () => {
      const srcChainId = get(srcChain)?.id;
      if (srcChainId && srcChainId !== prevChainId) {
        resolve();
      } else {
        setTimeout(waitForNetworkChange, 300);
      }
    };

    waitForNetworkChange();
  });
}
