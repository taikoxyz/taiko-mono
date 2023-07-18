import { fetchSigner, watchAccount, watchNetwork } from 'wagmi/actions';

import { mainnetChain } from '../chain/chains';
import { srcChain } from '../store/chain';
import { isSwitchChainModalOpen } from '../store/modal';
import { signer } from '../store/signer';
import { getLogger } from '../utils/logger';

const log = getLogger('wagmi:watcher');

let isWatching = false;
let unWatchNetwork: () => void;
let unWatchAccount: () => void;

const setChain = (chainId: number) => {
  if (chainId === mainnetChain.id) {
    srcChain.set(mainnetChain);

    log(`Network switched to ${mainnetChain.name}`);
  } else {
    isSwitchChainModalOpen.set(true);
  }
};

export function startWatching() {
  if (!isWatching) {
    // Action for subscribing to network changes.
    // See https://wagmi.sh/core/actions/watchNetwork
    unWatchNetwork = watchNetwork(async (networkResult) => {
      log('Network changed', networkResult);

      if (networkResult.chain?.id) {
        const _signer = await fetchSigner();
        signer.set(_signer);

        setChain(networkResult.chain.id);
      } else {
        log('No chain id found');
        srcChain.set(null);
      }
    });

    // Action for subscribing to account changes.
    // See https://wagmi.sh/core/actions/watchAccount
    unWatchAccount = watchAccount(async (accountResult) => {
      log('Account changed', accountResult);

      if (accountResult.isConnected) {
        const _signer = await fetchSigner();
        signer.set(_signer);
      } else {
        log('Acount disconnected');
        signer.set(null);
      }
    });

    isWatching = true;
  }
}

export function stopWatching() {
  unWatchNetwork();
  unWatchAccount();
  isWatching = false;
}
