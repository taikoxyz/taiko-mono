import { providers } from 'ethers';
import { type Chain, useNetwork,type WalletClient } from 'wagmi';
import { getWalletClient, watchAccount, watchNetwork } from 'wagmi/actions';

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

// fetchSigner (now getWalletClient)
// https://wagmi.sh/core/migration-guide#getsigner
// However, we still have many places to use signer
// So we convert WalletClient to Signer
// https://wagmi.sh/react/ethers-adapters#wallet-client--signer
function walletClientToSigner(chain: Chain, walletClient: WalletClient) {
  const { account, transport } = walletClient;
  const network = {
    chainId: chain.id,
    name: chain.name,
    ensAddress: chain.contracts?.ensRegistry?.address,
  };
  const provider = new providers.Web3Provider(transport, network);
  const signer = provider.getSigner(account.address);
  return signer;
}

export function startWatching() {
  if (!isWatching) {
    // Action for subscribing to network changes.
    // See https://wagmi.sh/core/actions/watchNetwork
    unWatchNetwork = watchNetwork(async (networkResult) => {
      log('Network changed', networkResult);

      if (networkResult.chain?.id) {
        const walletClient = await getWalletClient();
        const _signer = walletClientToSigner(networkResult.chain, walletClient);
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
      const { chain } = useNetwork();

      if (accountResult.isConnected) {
        const walletClient = await getWalletClient();
        const _signer = walletClientToSigner(chain, walletClient);
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
