import type { BridgeTransaction } from '$libs/bridge';

type MergeResult = {
  mergedTransactions: BridgeTransaction[];
  outdatedLocalTransactions: BridgeTransaction[];
};

export const mergeAndCaptureOutdatedTransactions = (
  localTxs: BridgeTransaction[],
  relayerTx: BridgeTransaction[],
): MergeResult => {
  // Indexed both ways because a local transaction only carries a message hash once its
  // receipt has been read; matching on the transaction hash alone would instead retire a
  // local message because a *different* message from the same transaction came back
  const relayerMsgHashes = new Set(relayerTx.map((tx) => tx.msgHash).filter(Boolean));
  const relayerSrcTxHashes = new Set(relayerTx.map((tx) => tx.srcTxHash));

  const supersededByRelayer = (tx: BridgeTransaction) =>
    tx.msgHash ? relayerMsgHashes.has(tx.msgHash) : relayerSrcTxHashes.has(tx.srcTxHash);

  const outdatedLocalTransactions: BridgeTransaction[] = [];
  const mergedTransactions: BridgeTransaction[] = [];

  for (const tx of localTxs) {
    if (supersededByRelayer(tx)) {
      outdatedLocalTransactions.push(tx);
    } else {
      mergedTransactions.push(tx);
    }
  }

  for (const tx of relayerTx) {
    mergedTransactions.push(tx);
  }

  return { mergedTransactions, outdatedLocalTransactions };
};
