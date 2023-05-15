import { fetchSigner, watchAccount, watchNetwork } from '@wagmi/core';
import { getLogger } from '../utils/logger';
import { fromChain, toChain } from '../store/chain';
import { signer } from '../store/signer';
import { bridgeChains } from '../chain/chains';
import { bridgeChainType } from '../store/bridge';
import { get } from 'svelte/store';
import { isSwitchEthereumChainModalOpen } from '../store/modal';

const log = getLogger('wagmi:watcher');

let isWatching = false;
let unWatchNetwork: () => void;
let unWatchAccount: () => void;

const changeChain = (chainId: number) => {
  const [chain1, chain2] = bridgeChains[get(bridgeChainType)];

  if (chainId === chain1.id) {
    fromChain.set(chain1);
    toChain.set(chain2);
  } else if (chainId === chain2.id) {
    fromChain.set(chain2);
    toChain.set(chain1);
  } else {
    isSwitchEthereumChainModalOpen.set(true);
  }
};

async function setSigner() {
  const _signer = await fetchSigner();
  signer.set(_signer);
  return _signer;
}

export function startWatching() {
  if (!isWatching) {
    // Action for subscribing to network changes.
    // See https://wagmi.sh/core/actions/watchNetwork
    unWatchNetwork = watchNetwork(async (networkResult) => {
      log('Network changed', networkResult);
      await setSigner();
      changeChain(networkResult.chain.id);
    });

    // Action for subscribing to account changes.
    // See https://wagmi.sh/core/actions/watchAccount
    unWatchAccount = watchAccount(async (accountResult) => {
      log('Account changed', accountResult);
      await setSigner();
    });

    isWatching = true;
  }
}

export function stopWatching() {
  unWatchNetwork();
  unWatchAccount();
  isWatching = false;
}
