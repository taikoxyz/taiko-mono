import { log } from 'debug';

import type { BridgeTransaction } from '$libs/bridge';

export const mergeUniqueTransactions = (
  localTxs: BridgeTransaction[],
  relayerTx: BridgeTransaction[],
): BridgeTransaction[] => {
  const keyForTransaction = (tx: BridgeTransaction): string => `${tx.status}-${tx.msgHash}-${tx.hash}`;

  const uniqueTransactionsMap = [...localTxs, ...relayerTx].reduce((map, transaction) => {
    const key = keyForTransaction(transaction);
    if (!map.has(key)) {
      map.set(key, transaction);
    } else {
      log('duplicate transaction', transaction.hash);
    }
    return map;
  }, new Map<string, BridgeTransaction>());

  return Array.from(uniqueTransactionsMap.values());
};
