import { watchAccount, watchNetwork /*, watchPublicClient, watchWalletClient*/ } from '@wagmi/core';

import { getLogger } from '$libs/util/logger';
import { account } from '$stores/account';
import { network } from '$stores/network';

const log = getLogger('wagmi:watcher');

let isWatching = false;
let unWatchNetwork: () => void;
let unWatchAccount: () => void;

export function startWatching() {
  if (!isWatching) {
    // Action for subscribing to network changes.
    // See https://wagmi.sh/core/actions/watchNetwork
    unWatchNetwork = watchNetwork((data) => {
      log('Network changed', data);

      // When we switch networks, we are actually selecting
      // the source chain.
      network.set(data.chain);
    });

    // Action for subscribing to account changes.
    // See https://wagmi.sh/core/actions/watchAccount
    unWatchAccount = watchAccount((data) => {
      log('Account changed', data);

      account.set(data);
    });

    isWatching = true;
  }
}

export function stopWatching() {
  unWatchNetwork();
  unWatchAccount();
  isWatching = false;
}
