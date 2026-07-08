"use client";

import {
  getAccount,
  type GetAccountReturnType,
  watchAccount,
} from "@wagmi/core";

import { chains, isSupportedChain } from "@/libs/chain";
import { refreshUserBalance } from "@/libs/util/balance";
import { checkForPausedContracts } from "@/libs/util/checkForPausedContracts";
import { isSmartContract } from "@/libs/util/isSmartContract";
import { getLogger } from "@/libs/util/logger";
import { account, connectedSmartContractWallet } from "@/stores/account";
import { modalStore } from "@/stores/useModalStore";
import { connectedSourceChain } from "@/stores/network";

import { config, reconnectionPromise } from "./client";

const log = getLogger("wagmi:watcher");

let isWatching = false;
let unWatchAccount: (() => void) | undefined;
// Incremented by every start/stop so an in-flight startWatching (suspended on
// reconnectionPromise) can detect it was superseded — under React StrictMode
// the mount effect's cleanup runs while the first start is still awaiting.
let watchGeneration = 0;

async function handleAccountChange(data: GetAccountReturnType) {
  await checkForPausedContracts();
  log("Account changed", data);
  account.setState(data);

  refreshUserBalance();
  const { chainId, address } = data;

  if (chainId && address) {
    let smartWallet = false;
    try {
      smartWallet = (await isSmartContract(address, Number(chainId))) || false;
    } catch (error) {
      console.error("Error checking for smart contract wallet", error);
    } finally {
      connectedSmartContractWallet.setState(smartWallet);
    }
  }

  // We need to check if the chain is supported, and if not
  // we present the user with a modal to switch networks.
  if (chainId && !isSupportedChain(Number(chainId))) {
    log("Unsupported chain", chainId);
    modalStore.getState().setSwitchChainModal(true);
    return;
  } else if (chainId) {
    // When we switch networks, we are actually selecting
    // the source chain.
    const srcChain = chains.find((c) => c.id === Number(chainId));
    if (srcChain) connectedSourceChain.setState(srcChain);
    refreshUserBalance();
  }
}

export async function startWatching() {
  checkForPausedContracts();

  if (isWatching) return;
  // Claim the watching slot SYNCHRONOUSLY so a concurrent startWatching
  // (e.g. StrictMode's remounted effect) cannot start a second subscription
  // while this one is still awaiting the reconnection below.
  isWatching = true;
  const generation = ++watchGeneration;

  // Wait for wagmi reconnection to complete before checking initial state
  // This ensures we get the correct connection status
  try {
    await reconnectionPromise;
  } catch (error) {
    log("Reconnection failed or not needed", error);
  }

  // A stopWatching (or a newer start) superseded this call while it was
  // suspended — abandon it without registering a watcher.
  if (generation !== watchGeneration) return;

  // Get initial account state and sync it immediately
  const initialAccount = getAccount(config);
  log("Initial account state", initialAccount);
  account.setState(initialAccount);

  // Handle initial account state if connected
  if (initialAccount.isConnected) {
    await handleAccountChange(initialAccount);
    if (generation !== watchGeneration) return;
  }

  // Set up watcher for future changes
  unWatchAccount = watchAccount(config, {
    onChange: handleAccountChange,
  });
}

export function stopWatching() {
  watchGeneration++;
  unWatchAccount?.();
  unWatchAccount = undefined;
  isWatching = false;
}
