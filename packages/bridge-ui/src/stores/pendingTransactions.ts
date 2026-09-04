import { getPublicClient } from '@wagmi/core';
import { writable } from 'svelte/store';
import {
  type Hex,
  type ReplacementReturnType,
  type TransactionReceipt,
  WaitForTransactionReceiptTimeoutError,
} from 'viem';

import { pendingTransaction } from '$config';
import { FailedTransactionError, ReceiptUnavailableError, TransactionTimeoutError } from '$libs/error';
import { refreshUserBalance } from '$libs/util/balance';
import { Deferred } from '$libs/util/Deferred';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

const log = getLogger('store:pendingTransactions');

// Custom store: pendingTransactions
const { subscribe, set, update } = writable<Hex[]>([]);
export const pendingTransactions = {
  /**
   * We're creating here a custom store, which is a writable store.
   * We must stick to the store contract, which is:
   */
  set,
  subscribe,
  // update, // this method is optional.

  /**
   * Custom method, which will help us add a new transaction to the store
   * and get it removed once the transaction is mined.
   */
  add: (hash: Hex, chainId: number) => {
    const deferred = new Deferred<TransactionReceipt>();

    update((hashes: Hex[]) => {
      // New array with the new transaction appended
      const newPendingTransactions = [...hashes, hash];

      // Next step is to wait for the transaction to be mined
      // before removing it from the store.

      /**
       * Waits on the chain's own client rather than through @wagmi/core's wrapper. The
       * wrapper never returns a reverted receipt: it re-simulates the transaction and throws
       * a plain Error for it, so a revert never reached the status check below and landed in
       * the catch instead - where anything that is not a timeout reads as "the receipt could
       * not be read", which every caller treats as a transaction that may still confirm.
       *
       * Returns a Promise which will not resolve until transactionHash is mined, or the
       * configured timeout has passed.
       */
      const client = getPublicClient(config, { chainId });
      // The wallet can replace the transaction under the same nonce, and the wait then
      // resolves with the replacement's receipt. A MetaMask "cancel" is a successful
      // 0-value self-transfer, so it read as "transaction completed" and was recorded in
      // the local history under a hash that never mined.
      let replacement: ReplacementReturnType | undefined;
      const receiptWait = client
        ? client.waitForTransactionReceipt({
            hash,
            timeout: pendingTransaction.waitTimeout,
            onReplaced: (details) => (replacement = details),
          })
        : Promise.reject(new Error(`no client configured for chain ${chainId}`));

      receiptWait
        .then((receipt) => {
          log('Transaction mined with receipt', receipt);

          log(`Removing transaction "${hash}" from store`);
          update((hashes: Hex[]) =>
            // Filter out the transaction with the given hash
            hashes.filter((_hash) => _hash !== hash),
          );

          // Resolves or rejects the promise depending on the transaction status.
          if (replacement && replacement.reason !== 'repriced') {
            // Cancelled, or replaced by something else: what the user asked for never ran.
            // A repriced transaction is the same call under a new hash, and its receipt is
            // the one that counts - callers that record the hash take it from there.
            deferred.reject(
              new FailedTransactionError(`transaction with hash "${hash}" was ${replacement.reason} in the wallet`, {
                cause: replacement,
              }),
            );
          } else if (receipt.status === 'success') {
            log('Transaction successful');
            deferred.resolve(receipt);
          } else {
            deferred.reject(new FailedTransactionError(`transaction with hash "${hash}" failed`, { cause: receipt }));
          }
        })
        .catch((err) => {
          console.error(err);
          // Neither of these means the transaction failed - only a reverted receipt does,
          // and that is rejected above. Callers branch on them to keep a still live
          // transaction from being reported, and re-offered, as a failed one
          if (err instanceof WaitForTransactionReceiptTimeoutError) {
            deferred.reject(new TransactionTimeoutError(`transaction with hash "${hash}" timed out`, { cause: err }));
          } else {
            deferred.reject(
              new ReceiptUnavailableError(`could not read the receipt for transaction "${hash}"`, { cause: err }),
            );
          }
        })
        .finally(() => {
          refreshUserBalance();
        });

      return newPendingTransactions;
    });

    // TODO: return deferred object instead, so we can cancel the promise
    //       in case we need it, e.g.: poller picks up already claimed transaction
    //       by the relayer, in which case we don't need to wait for this transaction
    //       to finish
    return deferred.promise;
  },
};
