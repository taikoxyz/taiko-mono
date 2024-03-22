import type { Address } from 'viem';

import { relayerApiServices } from '$libs/relayer';
import { bridgeTxService } from '$libs/storage';
import { getLogger } from '$libs/util/logger';
import { mergeAndCaptureOutdatedTransactions } from '$libs/util/mergeTransactions';

import { type BridgeTransaction, MessageStatus } from './types';

const log = getLogger('bridge:fetchTransactions');
let error: Error;

export async function fetchTransactions(userAddress: Address) {
  // Transactions from local storage
  const localTxs: BridgeTransaction[] = await bridgeTxService.getAllTxByAddress(userAddress);

  // Get all transactions from all relayers
  const relayerTxPromises: Promise<BridgeTransaction[]>[] = relayerApiServices.map(async (relayerApiService) => {
    const { txs } = await relayerApiService.getAllBridgeTransactionByAddress(userAddress, {
      page: 0,
      size: 100,
    });
    log(`fetched ${txs?.length ?? 0} transactions from relayer`, txs);
    return txs;
  });

  let relayerTxsArrays: BridgeTransaction[][];
  // Wait for all promises to resolve
  try {
    relayerTxsArrays = await Promise.all(relayerTxPromises);
  } catch (e) {
    log('error fetching transactions from relayers', e);
    error = e as Error;
    relayerTxsArrays = [];
  }

  // Flatten the arrays into a single array
  const relayerTxsFlattened = relayerTxsArrays.reduce((acc, txs) => acc.concat(txs), []);

  // Reverse the flattened array to sort transactions in descending order, placing the most recent transactions first
  const relayerTxs: BridgeTransaction[] = relayerTxsFlattened.reverse();

  log(`fetched ${relayerTxs?.length ?? 0} transactions from all relayers`, relayerTxs);

  const { mergedTransactions, outdatedLocalTransactions } = mergeAndCaptureOutdatedTransactions(localTxs, relayerTxs);
  if (outdatedLocalTransactions.length > 0) {
    log(
      `found ${outdatedLocalTransactions.length} outdated transaction(s)`,
      outdatedLocalTransactions.map((tx) => tx.hash),
    );
  }

  // Sort by status
  const statusOrder: MessageStatus[] = [
    MessageStatus.NEW,
    MessageStatus.RETRIABLE,
    MessageStatus.FAILED,
    MessageStatus.DONE,
  ];

  mergedTransactions.sort((a: BridgeTransaction, b: BridgeTransaction) => {
    const aStatusIndex = a.msgStatus !== undefined ? statusOrder.indexOf(a.msgStatus) : -1;
    const bStatusIndex = b.msgStatus !== undefined ? statusOrder.indexOf(b.msgStatus) : -1;
    return aStatusIndex - bStatusIndex;
  });
  return { mergedTransactions, outdatedLocalTransactions, error };
}
