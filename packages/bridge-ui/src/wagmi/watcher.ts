import { fetchSigner, watchAccount, watchNetwork } from '@wagmi/core';
import { getLogger } from '../utils/logger';
import { fromChain, toChain } from '../store/chain';
import { signer } from '../store/signer';
import { isSwitchEthereumChainModalOpen } from '../store/modal';
import { mainnetChain, taikoChain } from '../chain/chains';

const log = getLogger('wagmi:watcher');

let isWatching = false;
let unWatchNetwork: () => void;
let unWatchAccount: () => void;

const changeChain = (chainId: number) => {
  if (chainId === mainnetChain.id) {
    fromChain.set(mainnetChain);
    toChain.set(taikoChain);
  } else if (chainId === taikoChain.id) {
    fromChain.set(taikoChain);
    toChain.set(mainnetChain);
  } else {
    isSwitchEthereumChainModalOpen.set(true);
  }
};

export function startWatching() {
  if (!isWatching) {
    // Action for subscribing to network changes.
    // See https://wagmi.sh/core/actions/watchNetwork
    unWatchNetwork = watchNetwork((networkResult) => {
      log('Network changed', networkResult);

      if (networkResult.chain?.id) {
        changeChain(networkResult.chain.id);
      } else {
        log('No chain id found');
        fromChain.set(null);
        toChain.set(null);
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
