import type { BridgeTransaction } from '$libs/bridge';

import { getLogger } from './logger';

type MergeResult = {
  mergedTransactions: BridgeTransaction[];
  outdatedLocalTransactions: BridgeTransaction[];
}

export const mergeAndCaptureOutdatedTransactions = (
  localTxs: BridgeTransaction[],
  relayerTx: BridgeTransaction[],
): MergeResult => {

  const relayerTxMap = new Map<string, BridgeTransaction>();
  relayerTx.forEach(tx => relayerTxMap.set(tx.hash, tx));

  const outdatedLocalTransactions: BridgeTransaction[] = [];
  const mergedTransactions: BridgeTransaction[] = localTxs.map(tx => {
    const overrideTx = relayerTxMap.get(tx.hash);
    if (overrideTx) {
      outdatedLocalTransactions.push(tx);
      return overrideTx;
    }
    return tx;
  });

  relayerTx.forEach(tx => {
    if (!mergedTransactions.some(localTx => localTx.hash === tx.hash)) {
      mergedTransactions.push(tx);
    }
  });

  return { mergedTransactions, outdatedLocalTransactions };
};