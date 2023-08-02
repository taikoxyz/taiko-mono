import type { BridgeTransaction } from '$libs/bridge';

import { getLogger } from './logger';

export const mergeUniqueTransactions = (
  localTxs: BridgeTransaction[],
  relayerTx: BridgeTransaction[],
): BridgeTransaction[] => {
  const keyForTransaction = (tx: BridgeTransaction): string => `${tx.status}-${tx.msgHash}-${tx.hash}`;
  const log = getLogger('utils:mergeTransactions');

  const uniqueTransactionsMap = [...localTxs, ...relayerTx].reduce((map, transaction) => {
    const key = keyForTransaction(transaction);
    if (!map.has(key)) {
      map.set(key, transaction);
    } else {
      log('duplicate transaction', transaction.hash);
      //todo: remove the tx from storage
    }
    return map;
  }, new Map<string, BridgeTransaction>());

  return Array.from(uniqueTransactionsMap.values());
};
