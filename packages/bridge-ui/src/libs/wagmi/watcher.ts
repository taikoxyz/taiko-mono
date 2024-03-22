import { watchAccount } from '@wagmi/core';

import { chains, isSupportedChain } from '$libs/chain';
import { refreshUserBalance } from '$libs/util/balance';
import { checkForPausedContracts } from '$libs/util/checkForPausedContracts';
import { getLogger } from '$libs/util/logger';
import { account } from '$stores/account';
import { switchChainModal } from '$stores/modal';
import { connectedSourceChain } from '$stores/network';

import { config } from './client';
const log = getLogger('wagmi:watcher');

let isWatching = false;
let unWatchAccount: () => void;

export async function startWatching() {
  checkForPausedContracts();

  if (!isWatching) {
    unWatchAccount = watchAccount(config, {
      onChange(data) {
        checkForPausedContracts();
        log('Account changed', data);

        refreshUserBalance();
        const { chain } = data;

        // We need to check if the chain is supported, and if not
        // we present the user with a modal to switch networks.
        if (chain?.id && !isSupportedChain(Number(chain.id))) {
          log('Unsupported chain', chain);
          switchChainModal.set(true);
          return;
        } else if (chain?.id) {
          // When we switch networks, we are actually selecting
          // the source chain.
          const srcChain = chains.find((c) => c.id === Number(chain?.id));
          if (srcChain) connectedSourceChain.set(srcChain);

          refreshUserBalance();
        }
        account.set(data);
      },
    });

    isWatching = true;
  }
}

export function stopWatching() {
  unWatchAccount();
  isWatching = false;
}
