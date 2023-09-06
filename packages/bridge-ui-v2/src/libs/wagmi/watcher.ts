import { watchAccount, watchNetwork } from '@wagmi/core';

import { isSupportedChain } from '$libs/chain';
import { refreshUserBalance } from '$libs/util/balance';
import { getLogger } from '$libs/util/logger';
import { account } from '$stores/account';
import { switchChainModal } from '$stores/modal';
import { network } from '$stores/network';

const log = getLogger('wagmi:watcher');

let isWatching = false;
let unWatchNetwork: () => void;
let unWatchAccount: () => void;

export async function startWatching() {
  if (!isWatching) {
    // Action for subscribing to network changes.
    // See https://wagmi.sh/core/actions/watchNetwork
    unWatchNetwork = watchNetwork((data) => {
      log('Network changed', data);

      const { chain } = data;

      // We need to check if the chain is supported, and if not
      // we present the user with a modal to switch networks.
      if (chain && !isSupportedChain(Number(chain.id))) {
        log('Unsupported chain', chain);
        switchChainModal.set(true);
        return;
      }

      // When we switch networks, we are actually selecting
      // the source chain.
      network.set(chain);
      refreshUserBalance();
    });

    // Action for subscribing to account changes.
    // See https://wagmi.sh/core/actions/watchAccount
    unWatchAccount = watchAccount((data) => {
      log('Account changed', data);
      account.set(data);
      refreshUserBalance();
    });

    isWatching = true;
  }
}

export function stopWatching() {
  unWatchNetwork();
  unWatchAccount();
  isWatching = false;
}
