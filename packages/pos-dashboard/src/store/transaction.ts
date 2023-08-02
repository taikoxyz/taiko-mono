import { ethers, type Signer, type Transaction } from 'ethers';
import { writable } from 'svelte/store';

import type { TransactionReceipt } from '../domain/transaction';
import { Deferred } from '../utils/Deferred';
import { getLogger } from '../utils/logger';

const log = getLogger('store:transactions');

export const transactions = writable<TransactionReceipt[]>([]);

// Custom store: pendingTransactions
const { subscribe, set, update } = writable<Transaction[]>([]);
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
   * and get it removed onces the transaction is mined.
   */
  add: (tx: Transaction, signer: Signer) => {
    const deferred = new Deferred<TransactionReceipt>();

    update((txs: Transaction[]) => {
      // New array with the new transaction appended
      const newPendingTransactions = [...txs, tx];

      // Next step is to wait for the transaction to be mined
      // before removing it from the store.

      /**
       * Returns a Promise which will not resolve until transactionHash is mined.
       * If confirms is 0, this method is non-blocking and if the transaction
       * has not been mined returns null. Otherwise, this method will block until
       * the transaction has confirms blocks mined on top of the block in which
       * is was mined.
       * See https://docs.ethers.org/v5/api/providers/provider/#Provider-waitForTransaction
       */
      signer.provider
        .waitForTransaction(tx.hash, 1, 5 * 60 * 1000) // 5 min timeout. TODO: config?
        .then((receipt) => {
          log('Transaction mined with receipt', receipt);

          log(`Removing transaction "${tx.hash}" from store`);
          update((txs: Transaction[]) =>
            // Filter out the transaction with the given hash
            txs.filter((_tx) => _tx.hash !== tx.hash),
          );

          // Resolves or rejects the promise depending on the transaction status.
          if (receipt.status === 1) {
            log('Transaction successful');
            deferred.resolve(receipt);
          } else {
            deferred.reject(
              new Error('transaction failed', { cause: receipt }),
            );
          }
        })
        .catch((error) => {
          if (error?.code === ethers.errors.TIMEOUT) {
            deferred.reject(
              new Error('timeout while waiting for transaction to be mined', {
                cause: error,
              }),
            );
          } else {
            deferred.reject(
              new Error('transaction failed', {
                cause: error,
              }),
            );
          }
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
