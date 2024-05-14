import type { BridgeTransaction } from '$libs/bridge';

type MergeResult = {
  mergedTransactions: BridgeTransaction[];
  outdatedLocalTransactions: BridgeTransaction[];
};

export const mergeAndCaptureOutdatedTransactions = (
  localTxs: BridgeTransaction[],
  relayerTx: BridgeTransaction[],
): MergeResult => {
  const relayerTxMap: Map<string, BridgeTransaction> = new Map();
  relayerTx.forEach((tx) => relayerTxMap.set(tx.hash, tx));

  const outdatedLocalTransactions: BridgeTransaction[] = [];
  const mergedTransactions: BridgeTransaction[] = [];

  for (const tx of localTxs) {
    if (!relayerTxMap.has(tx.hash)) {
      mergedTransactions.push(tx);
    } else {
      outdatedLocalTransactions.push(tx);
    }
  }

  for (const tx of relayerTx) {
    mergedTransactions.push(tx);
  }

  return { mergedTransactions, outdatedLocalTransactions };
};
