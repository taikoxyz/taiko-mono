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
let unWatchAccount: (() => void) | undefined;
/**
 * Bumped by stopWatching. startWatching awaits the wallet reconnection before it installs
 * its subscription, and a layout torn down during that wait used to find nothing to
 * unwatch - then the await returned and installed a subscription nothing would ever remove.
 */
let watchGeneration = 0;

/**
 * The account event this handler is currently acting on. wagmi emits overlapping events -
 * `connecting` then `connected`, or a fast switch back and forth - and each one awaits, so
 * without this the earlier continuation can resume last and write its stale snapshot over
 * the newer one, leaving the app "disconnected" while the wallet is connected.
 */
let accountChangeGeneration = 0;

async function handleAccountChange(data: GetAccountReturnType) {
  const generation = ++accountChangeGeneration;
  log('Account changed', data);
  // Set first, and synchronously. Awaiting the pause check before this made every reader of
  // $account and $connectedSourceChain lag the real wallet by an RPC round trip, longer
  // when an endpoint is degraded - and the pause check does not describe the account, it
  // only decides whether a modal is raised.
  account.set(data);

  checkForPausedContracts().catch((error) => log('Pause check failed', error));

  refreshUserBalance();
  const { chainId, address } = data;

  if (chainId && address) {
    let smartWallet: boolean;
    try {
      smartWallet = (await isSmartContract(address, Number(chainId))) || false;
    } catch (error) {
      // Unknown is not "no". This flag is what routes a contract-wallet user through the
      // recipient acknowledgement; answering false for a read that never happened skipped
      // that gate for exactly the user it protects. A wallet whose code could not be read is
      // treated as a contract wallet: the cost is one extra confirmation for an EOA behind a
      // failing RPC, against a stranded message the other way.
      console.error('Could not classify the connected wallet; treating it as a contract wallet', error);
      smartWallet = true;
    }
    // A classification speaks for the account it ran against, not for whichever is current
    if (generation === accountChangeGeneration) connectedSmartContractWallet.set(smartWallet);
  }

  // Everything below decides what is on screen for this account, so a superseded event
  // must stop here rather than reinstate the previous chain's modal or source chain
  if (generation !== accountChangeGeneration) return;

  // We need to check if the chain is supported, and if not
  // we present the user with a modal to switch networks.
  if (chainId && !isSupportedChain(Number(chainId))) {
    log('Unsupported chain', chainId);
    switchChainModal.set(true);
    return;
  } else if (chainId) {
    // The wallet is (back) on a supported chain, so the switch-chain modal must not linger
    switchChainModal.set(false);
    // When we switch networks, we are actually selecting
    // the source chain.
    const srcChain = chains.find((c) => c.id === Number(chainId));
    if (srcChain) connectedSourceChain.set(srcChain);
    refreshUserBalance();
  } else {
    // Disconnected: there is no chain to switch away from anymore
    switchChainModal.set(false);
  }
}

/** @dev Exported for tests: the handler is otherwise only reachable through watchAccount. */
export const handleAccountChangeForTest = handleAccountChange;

export async function startWatching() {
  checkForPausedContracts();

  if (!isWatching) {
    const generation = watchGeneration;
    // Wait for wagmi reconnection to complete before checking initial state
    // This ensures we get the correct connection status
    try {
      await reconnectionPromise;
    } catch (error) {
      log('Reconnection failed or not needed', error);
    }

    // The layout that asked for this is gone; whoever mounts next starts its own
    if (generation !== watchGeneration) return;

    // Get initial account state and sync it immediately
    const initialAccount = getAccount(config);
    log('Initial account state', initialAccount);
    account.set(initialAccount);

    // Handle initial account state if connected
    if (initialAccount.isConnected) {
      await handleAccountChange(initialAccount);
      if (generation !== watchGeneration) return;
    }

    // Set up watcher for future changes
    unWatchAccount = watchAccount(config, {
      onChange: handleAccountChange,
    });

    isWatching = true;
  }
}

export function stopWatching() {
  // A layout can tear down before startWatching has awaited its way to the assignment,
  // which threw on a call that only means "there is nothing to unwatch"
  unWatchAccount?.();
  unWatchAccount = undefined;
  isWatching = false;
  watchGeneration++;
}
