// Ported from stores/pendingTransactions.ts.
//
// The original is a custom svelte store of `Hex[]` exposing `set`/`subscribe`
// plus a stateful `.add(hash, chainId)` method that: appends the hash, awaits
// `waitForTransactionReceipt`, removes the hash on mine, refreshes the user
// balance, and returns a `Deferred<TransactionReceipt>` promise that 5 components
// (ConfirmationStep, ClaimDialog, RetryDialog, ReleaseDialog, Faucet) await for
// success/failure branching.
//
// Migration plan: split into (a) a Zustand `Hex[]` list (reactive in-flight count)
// with vanilla get/set, and (b) a TanStack `useMutation` wrapping the receipt wait
// that invalidates the balance on settle. To keep the existing imperative,
// awaited-promise call sites working UNCHANGED, the `pendingTransactions` object
// below preserves the exact `set` / `subscribe` / `add(hash, chainId) => Promise`
// contract (backed by the vanilla list store). React UIs can additionally use the
// `usePendingTransactions` hook (reactive list) and the `useAddPendingTransaction`
// mutation hook. ALL business logic — receipt wait, success/timeout/failure
// rejection, balance refresh — is preserved verbatim.
"use client";

import { waitForTransactionReceipt } from "@wagmi/core";
import { useMutation } from "@tanstack/react-query";
import {
  type Hex,
  type TransactionReceipt,
  WaitForTransactionReceiptTimeoutError,
} from "viem";
import { useStore } from "zustand";
import { createValueStore } from "@/stores/createValueStore";

import { pendingTransaction } from "$config";
import { FailedTransactionError, TransactionTimeoutError } from "$libs/error";
import { refreshUserBalance } from "$libs/util/balance";
import { Deferred } from "$libs/util/Deferred";
import { getLogger } from "$libs/util/logger";
import { config } from "$libs/wagmi";

const log = getLogger("store:pendingTransactions");

// Vanilla zustand store backing the in-flight transaction hash list.
const listStore = createValueStore<Hex[]>(() => []);

/**
 * Custom store facade: preserves the original svelte writable contract
 * (`set`, `subscribe`) plus the bespoke `add` method.
 */
export const pendingTransactions = {
  /**
   * We're creating here a custom store, which is a writable store.
   * We must stick to the store contract, which is:
   */
  set: (value: Hex[]) => listStore.setState(value, true),
  subscribe: listStore.subscribe,
  // Imperative read (mirrors svelte's `get(pendingTransactions)`).
  getState: listStore.getState,
  // update, // this method is optional.

  /**
   * Custom method, which will help us add a new transaction to the store
   * and get it removed once the transaction is mined.
   */
  add: (hash: Hex, chainId: number) => {
    const deferred = new Deferred<TransactionReceipt>();

    const update = (updater: (hashes: Hex[]) => Hex[]) => {
      const next = updater(listStore.getState());
      listStore.setState(next, true);
      return next;
    };

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
          log("Transaction mined with receipt", receipt);

          log(`Removing transaction "${hash}" from store`);
          update((hashes: Hex[]) =>
            // Filter out the transaction with the given hash
            hashes.filter((_hash) => _hash !== hash),
          );

          // Resolves or rejects the promise depending on the transaction status.
          if (receipt.status === "success") {
            log("Transaction successful");
            deferred.resolve(receipt);
          } else {
            deferred.reject(
              new FailedTransactionError(
                `transaction with hash "${hash}" failed`,
                { cause: receipt },
              ),
            );
          }
        })
        .catch((err) => {
          console.error(err);
          if (err instanceof WaitForTransactionReceiptTimeoutError) {
            deferred.reject(
              new TransactionTimeoutError(
                `transaction with hash "${hash}" timed out`,
                { cause: err },
              ),
            );
          }
          deferred.reject(
            new FailedTransactionError(
              `transaction with hash "${hash}" failed`,
              { cause: err },
            ),
          );
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

/**
 * React hook over the reactive in-flight transaction list (e.g. for a pending
 * badge / count). Defaults to selecting the whole `Hex[]`.
 */
export function usePendingTransactions<T = Hex[]>(
  selector: (state: Hex[]) => T = (s) => s as unknown as T,
): T {
  return useStore(listStore, selector);
}

/**
 * TanStack React Query mutation wrapping `pendingTransactions.add`. `mutateAsync`
 * preserves the awaited-promise contract (resolves with the receipt on success,
 * rejects with FailedTransactionError / TransactionTimeoutError otherwise), and
 * the underlying `add` already refreshes the balance in its `finally`.
 */
export function useAddPendingTransaction() {
  return useMutation<TransactionReceipt, Error, { hash: Hex; chainId: number }>(
    {
      mutationFn: ({ hash, chainId }) => pendingTransactions.add(hash, chainId),
    },
  );
}
