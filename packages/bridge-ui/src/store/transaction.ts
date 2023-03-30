import { writable, get } from 'svelte/store';

import type { Transaction } from 'ethers';
import type { BridgeTransaction } from '../domain/transaction';
import { signer } from './signer';

export const transactions = writable<BridgeTransaction[]>([]);

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
  add: (tx: Transaction, onMined?: () => void) => {
    update((txs: Transaction[]) => {
      // New array with the new transaction appended
      const newPendingTransactions = [...txs, tx];

      // Save the index of the new transaction
      const idxAppendedTransaction = newPendingTransactions.length - 1;

      // Next step is to wait for the transaction to be mined
      // before removing it from the store.
      get(signer)
        /**
         * Returns a Promise which will not resolve until transactionHash is mined.
         * If confirms is 0, this method is non-blocking and if the transaction
         * has not been mined returns null. Otherwise, this method will block until
         * the transaction has confirms blocks mined on top of the block in which
         * is was mined.
         * See https://docs.ethers.org/v5/api/providers/provider/#Provider-waitForTransaction
         */
        .provider.waitForTransaction(tx.hash, 1)
        .then(() => {
          // The transaction has been mined. Anything to run?
          onMined?.();

          // Removes the transaction from the store
          update((txs: Transaction[]) => {
            const copyPendingTransactions = [...txs];
            copyPendingTransactions.splice(idxAppendedTransaction, 1);
            return copyPendingTransactions;
          });
        });

      return newPendingTransactions;
    });
  },
};
