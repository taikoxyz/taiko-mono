import type { Address } from 'viem';

import { relayerApiServices } from '$libs/relayer';
import { bridgeTxService } from '$libs/storage';
import { getLogger } from '$libs/util/logger';
import { mergeAndCaptureOutdatedTransactions } from '$libs/util/mergeTransactions';

import { type BridgeTransaction, MessageStatus } from './types';

const log = getLogger('bridge:fetchTransactions');

const RELAYER_PAGE_SIZE = 500;
// Backstop against unbounded relayer histories; each page is one API call
const MAX_RELAYER_PAGES = 10;

async function fetchAllRelayerPages(
  relayerApiService: (typeof relayerApiServices)[number],
  userAddress: Address,
  chainId?: number,
): Promise<{ txs: BridgeTransaction[]; failedCount: number }> {
  const txs: BridgeTransaction[] = [];
  let failedCount = 0;

  for (let page = 0; page < MAX_RELAYER_PAGES; page++) {
    let pageTxs;
    let paginationInfo;
    let pageFailedCount;
    try {
      ({
        txs: pageTxs,
        paginationInfo,
        failedCount: pageFailedCount,
      } = await relayerApiService.getAllBridgeTransactionByAddress(
        userAddress,
        { page, size: RELAYER_PAGE_SIZE },
        chainId,
      ));
    } catch (error) {
      // Keep the pages already fetched: losing a later page should degrade the history,
      // not blank it. With nothing fetched yet the caller still needs to hear about it.
      if (txs.length === 0) throw error;
      log(`relayer page ${page} failed, returning ${txs.length} transactions already fetched`, error);
      break;
    }
    txs.push(...pageTxs);
    failedCount += pageFailedCount;

    if (paginationInfo.max_page === undefined || page >= paginationInfo.max_page) break;
    if (page === MAX_RELAYER_PAGES - 1) {
      log(`relayer history truncated at ${MAX_RELAYER_PAGES} pages for ${userAddress}`);
    }
  }
  return { txs, failedCount };
}

export async function fetchTransactions(userAddress: Address, chainId?: number) {
  // The error must be scoped per call: a module-level variable would keep reporting
  // "relayer offline" on every later, successful fetch
  let error: Error | undefined = undefined;

  // Transactions from local storage
  const localTxs: BridgeTransaction[] = await bridgeTxService.getAllTxByAddress(userAddress);

  // Get all transactions from all relayers
  const relayerTxPromises: Promise<{ txs: BridgeTransaction[]; failedCount: number }>[] = relayerApiServices.map(
    async (relayerApiService) => {
      const result = await fetchAllRelayerPages(relayerApiService, userAddress, chainId);
      log(`fetched ${result.txs.length} transactions from relayer`, result.txs);
      return result;
    },
  );

  let relayerResults: { txs: BridgeTransaction[]; failedCount: number }[];
  // Wait for all promises to resolve
  try {
    relayerResults = await Promise.all(relayerTxPromises);
  } catch (e) {
    log('error fetching transactions from relayers', e);
    error = e as Error;
    relayerResults = [];
  }

  const failedCount = relayerResults.reduce((total, result) => total + result.failedCount, 0);

  // Flatten the arrays into a single array, dropping duplicate hashes the relayer
  // may return across pages or relayers
  const relayerTxsFlattened = relayerResults.reduce((acc, result) => acc.concat(result.txs), [] as BridgeTransaction[]);
  const seenTxHashes = new Set<string>();
  const dedupedRelayerTxs = relayerTxsFlattened.filter((tx) => {
    if (seenTxHashes.has(tx.srcTxHash)) return false;
    seenTxHashes.add(tx.srcTxHash);
    return true;
  });

  // Reverse the flattened array to sort transactions in descending order, placing the most recent transactions first
  const relayerTxs: BridgeTransaction[] = dedupedRelayerTxs.reverse();

  log(`fetched ${relayerTxs?.length ?? 0} transactions from all relayers`, relayerTxs);

  const { mergedTransactions, outdatedLocalTransactions } = mergeAndCaptureOutdatedTransactions(localTxs, relayerTxs);
  if (outdatedLocalTransactions.length > 0) {
    log(
      `found ${outdatedLocalTransactions.length} outdated transaction(s)`,
      outdatedLocalTransactions.map((tx) => tx.srcTxHash),
    );
  }

  // Sort by status
  const statusOrder: MessageStatus[] = [
    MessageStatus.NEW,
    MessageStatus.RETRIABLE,
    MessageStatus.FAILED,
    MessageStatus.RECALLED,
    MessageStatus.DONE,
  ];

  mergedTransactions.sort((a: BridgeTransaction, b: BridgeTransaction) => {
    const aStatusIndex = a.msgStatus !== undefined ? statusOrder.indexOf(a.msgStatus) : -1;
    const bStatusIndex = b.msgStatus !== undefined ? statusOrder.indexOf(b.msgStatus) : -1;
    return aStatusIndex - bStatusIndex;
  });
  return { mergedTransactions, outdatedLocalTransactions, error, failedCount };
}
