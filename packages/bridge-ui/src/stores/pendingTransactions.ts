import { waitForTransactionReceipt } from '@wagmi/core';
import { writable } from 'svelte/store';
import type { Hex, TransactionReceipt } from 'viem';

import { pendingTransaction } from '$config';
import { FailedTransactionError } from '$libs/error';
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
       * Returns a Promise which will not resolve until transactionHash is mined.
       * If confirms is 0, this method is non-blocking and if the transaction
       * has not been mined returns null. Otherwise, this method will block until
       * the transaction has confirms blocks mined on top of the block in which
       * is was mined.
       */
      waitForTransactionReceipt(config, {
        hash,
        chainId,
        timeout: pendingTransaction.waitTimeout,
      })
        .then((receipt) => {
          log('Transaction mined with receipt', receipt);

          log(`Removing transaction "${hash}" from store`);
          update((hashes: Hex[]) =>
            // Filter out the transaction with the given hash
            hashes.filter((_hash) => _hash !== hash),
          );

          // Resolves or rejects the promise depending on the transaction status.
          if (receipt.status === 'success') {
            log('Transaction successful');
            deferred.resolve(receipt);
          } else {
            deferred.reject(new FailedTransactionError(`transaction with hash "${hash}" failed`, { cause: receipt }));
          }
        })
        .catch((err) => {
          console.error(err);
          deferred.reject(new FailedTransactionError(`transaction with hash "${hash}" failed`, { cause: err }));
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
