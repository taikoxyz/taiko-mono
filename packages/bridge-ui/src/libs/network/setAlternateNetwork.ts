import { get } from 'svelte/store';

import { destNetwork } from '$components/Bridge/state';
import { chainIdToChain } from '$libs/chain';
import { account } from '$stores/account';

import { getAlternateNetwork } from './getAlternateNetwork';

export const setAlternateNetwork = () => {
  if (get(account) && (get(account).isConnected || get(account).isConnecting)) {
    const alternateChainID = getAlternateNetwork();
    if (alternateChainID) {
      destNetwork.set(chainIdToChain(alternateChainID));
    }
  } else {
    destNetwork.set(null);
  }
};
