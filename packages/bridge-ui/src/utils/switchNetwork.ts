import { get } from 'svelte/store';
import { switchNetwork as wagmiSwitchNetwork } from 'wagmi/actions';

import { srcChain } from '../store/chain';
import { Deferred } from './Deferred';

export async function switchNetwork(chainId: number) {
  const prevChainId = get(srcChain)?.id;

  if (prevChainId === chainId) return;

  await wagmiSwitchNetwork({ chainId });

  // What are we doing here? we have a watcher waiting for network changes.
  // When this happens this watcher is called and takes care of setting
  // the signer and chains in the store. We are actually waiting here
  // for these stores to change due to some race conditions in the UI.
  // There will be a better design around this in alpha-4: fewer stores
  // and '$:' tags. They're evil.
  const deferred = new Deferred<void>();

  // This will prevent an unlikely infinite loop
  const starting = Date.now();
  const timeout = 5000; // TODO: config?

  const waitForNetworkChange = () => {
    const srcChainId = get(srcChain)?.id;

    if (srcChainId && srcChainId !== prevChainId) {
      // We have finally set the chain in the store. We're done here.
      deferred.resolve();
    } else if (Date.now() > starting + timeout) {
      // Wait, what???
      deferred.reject(new Error('timeout switching network'));
    } else {
      setTimeout(waitForNetworkChange, 300); // TODO: config those 300?
    }
  };

  waitForNetworkChange();

  return deferred.promise;
}
