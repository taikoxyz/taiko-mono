import { writable } from "svelte/store";

import { ethers, Signer, Transaction } from "ethers";
import type { BridgeTransaction, Transactioner } from "../domain/transactions";
import { StorageService } from "../storage/service";
import { successToast } from "../utils/toast";
import { MessageStatus } from "../domain/message";
import { chains } from "../domain/chain";
import BridgeABI from "../constants/abi/Bridge";

const pendingTransactions = writable<Transaction[]>([]);
const transactions = writable<BridgeTransaction[]>([]);
const transactioner = writable<Transactioner>();
const showTransactionDetails = writable<BridgeTransaction>();
const showMessageStatusTooltip = writable<boolean>();

export {
  pendingTransactions,
  transactions,
  transactioner,
  showTransactionDetails,
  showMessageStatusTooltip,
};

export function setTransactioner(
  providerMap: Map<number, ethers.providers.JsonRpcProvider>,
  localStorage: Storage
) {
  const storageTransactioner: Transactioner = new StorageService(
    localStorage,
    providerMap
  );

  transactioner.set(storageTransactioner);

  return transactioner;
}

export function subscribeToPendingTransactions(
  signer: Signer,
  transactioner: Transactioner
) {
  pendingTransactions.subscribe((store) => {
    store.forEach(async (tx) => {
      await signer.provider.waitForTransaction(tx.hash, 1);
      successToast("Transaction completed!");

      // TODO: Fix, .pop() removes the last tx but the confirmed tx is not necessarily the last one in the pendingTransactions array.
      const s = store;
      s.pop();
      pendingTransactions.set(s);

      // TODO: Do we need this?
      transactions.set(
        await transactioner.GetAllByAddress(await signer.getAddress())
      );
    });
  });
}

export function subscribeToTransactions(
  providerMap: Map<number, ethers.providers.JsonRpcProvider>
) {
  const transactionToIntervalMap = new Map<
    string,
    ReturnType<typeof setInterval>
  >();

  transactions.subscribe((store) => {
    if (store) {
      store.forEach(async (tx) => {
        const txInterval = transactionToIntervalMap.get(tx.hash);
        if (txInterval) {
          clearInterval(txInterval);
          transactionToIntervalMap.delete(tx.hash);
        }

        if (tx.status === MessageStatus.New) {
          const provider = providerMap.get(tx.toChainId);

          const interval = setInterval(async () => {
            const txInterval = transactionToIntervalMap.get(tx.hash);
            if (txInterval !== interval) {
              clearInterval(txInterval);
              transactionToIntervalMap.delete(tx.hash);
            }

            transactionToIntervalMap.set(tx.hash, interval);
            if (!tx.msgHash) return;

            const contract = new ethers.Contract(
              chains[tx.toChainId].bridgeAddress,
              BridgeABI,
              provider
            );

            const messageStatus: MessageStatus =
              await contract.getMessageStatus(tx.msgHash);

            if (messageStatus === MessageStatus.Done) {
              successToast("Bridge message processed successfully");
              const txOngoingInterval = transactionToIntervalMap.get(tx.hash);
              clearInterval(txOngoingInterval);
              transactionToIntervalMap.delete(tx.hash);
            }
          }, 20 * 1000);
        }
      });
    }
  });

  return transactions;
}
