import { getAccount, type GetAccountReturnType, watchAccount } from '@wagmi/core';

import { chains, isSupportedChain } from '$libs/chain';
import { refreshUserBalance } from '$libs/util/balance';
import { checkForPausedContracts } from '$libs/util/checkForPausedContracts';
import { isSmartContract } from '$libs/util/isSmartContract';
import { getLogger } from '$libs/util/logger';
import { account, connectedSmartContractWallet } from '$stores/account';
import { switchChainModal } from '$stores/modal';
import { connectedSourceChain } from '$stores/network';

import { config, reconnectionPromise } from './client';

const log = getLogger('wagmi:watcher');

let isWatching = false;
let unWatchAccount: () => void;

async function handleAccountChange(data: GetAccountReturnType) {
  await checkForPausedContracts();
  log('Account changed', data);
  account.set(data);

  refreshUserBalance();
  const { chainId, address } = data;

  if (chainId && address) {
    let smartWallet = false;
    try {
      smartWallet = (await isSmartContract(address, Number(chainId))) || false;
    } catch (error) {
      console.error('Error checking for smart contract wallet', error);
    } finally {
      connectedSmartContractWallet.set(smartWallet);
    }
  }

  // We need to check if the chain is supported, and if not
  // we present the user with a modal to switch networks.
  if (chainId && !isSupportedChain(Number(chainId))) {
    log('Unsupported chain', chainId);
    switchChainModal.set(true);
    return;
  } else if (chainId) {
    // When we switch networks, we are actually selecting
    // the source chain.
    const srcChain = chains.find((c) => c.id === Number(chainId));
    if (srcChain) connectedSourceChain.set(srcChain);
    refreshUserBalance();
  }
}

export async function startWatching() {
  checkForPausedContracts();

  if (!isWatching) {
    // Wait for wagmi reconnection to complete before checking initial state
    // This ensures we get the correct connection status
    try {
      await reconnectionPromise;
    } catch (error) {
      log('Reconnection failed or not needed', error);
    }

    // Get initial account state and sync it immediately
    const initialAccount = getAccount(config);
    log('Initial account state', initialAccount);
    account.set(initialAccount);

    // Handle initial account state if connected
    if (initialAccount.isConnected) {
      await handleAccountChange(initialAccount);
    }

    // Set up watcher for future changes
    unWatchAccount = watchAccount(config, {
      onChange: handleAccountChange,
    });

    isWatching = true;
  }
}

export function stopWatching() {
  unWatchAccount();
  isWatching = false;
}
