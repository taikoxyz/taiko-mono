import type { Address, Hash } from 'viem';

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
): Promise<{ txs: BridgeTransaction[]; failedTxHashes: Hash[]; error?: Error }> {
  const txs: BridgeTransaction[] = [];
  const failedTxHashes: Hash[] = [];

  for (let page = 0; page < MAX_RELAYER_PAGES; page++) {
    let pageTxs;
    let paginationInfo;
    let pageFailedTxHashes;
    try {
      ({
        txs: pageTxs,
        paginationInfo,
        failedTxHashes: pageFailedTxHashes,
      } = await relayerApiService.getAllBridgeTransactionByAddress(
        userAddress,
        { page, size: RELAYER_PAGE_SIZE },
        chainId,
      ));
    } catch (error) {
      // Keep the pages already fetched: losing a later page should degrade the history,
      // not blank it. Only a first-page failure means nothing was fetched at all, and the
      // caller needs to hear about that as a rejection. Keyed on the page index, not on
      // `txs.length`: a completed page whose rows all failed to enhance leaves `txs` empty
      // while still carrying failed hashes, and rethrowing there would discard them.
      if (page === 0) throw error;
      log(`relayer page ${page} failed, returning ${txs.length} transactions already fetched`, error);
      // Degrading is fine; degrading in silence is not. A partial history that looks
      // complete is the one outcome the user cannot tell apart from a correct one.
      // failedTxHashes carries what the completed pages already lost to failed on-chain reads.
      return { txs, failedTxHashes, error: error as Error };
    }
    txs.push(...pageTxs);
    failedTxHashes.push(...pageFailedTxHashes);

    if (paginationInfo.max_page === undefined || page >= paginationInfo.max_page) break;
    if (page === MAX_RELAYER_PAGES - 1) {
      log(`relayer history truncated at ${MAX_RELAYER_PAGES} pages for ${userAddress}`);
    }
  }
  return { txs, failedTxHashes };
}

export async function fetchTransactions(userAddress: Address, chainId?: number) {
  // The error must be scoped per call: a module-level variable would keep reporting
  // "relayer offline" on every later, successful fetch
  let error: Error | undefined = undefined;

  // Transactions from local storage
  const localTxs: BridgeTransaction[] = await bridgeTxService.getAllTxByAddress(userAddress);

  // Get all transactions from all relayers
  const relayerTxPromises = relayerApiServices.map(async (relayerApiService) => {
    const result = await fetchAllRelayerPages(relayerApiService, userAddress, chainId);
    log(`fetched ${result.txs?.length ?? 0} transactions from relayer`, result.txs);
    return result;
  });

  // allSettled, not all: relayers are independent sources, and one of them failing on its
  // first page must not throw away the history the others returned. Promise.all rejected
  // on the first failure and the catch blanked every result, so a single relayer being
  // offline showed the user an empty transaction list
  const relayerResults = await Promise.allSettled(relayerTxPromises);
  const relayerTxsArrays: BridgeTransaction[][] = [];
  // Only a relayer that answered can name the transactions it failed to load; a relayer that
  // rejected outright has nothing to report, and `error` speaks for it instead. Collected as a
  // set rather than summed: the same transaction can come back from several pages or several
  // relayers, and adding raw tallies would report one loss more than once
  const failedTxHashes = new Set<string>();
  for (const result of relayerResults) {
    if (result.status === 'fulfilled') {
      relayerTxsArrays.push(result.value.txs);
      for (const hash of result.value.failedTxHashes) failedTxHashes.add(hash);
      // A relayer that answered some pages and then failed still reports that failure,
      // so a partial history is not presented as a complete one
      if (result.value.error) {
        log('a relayer stopped part-way through its pages', result.value.error);
        error ??= result.value.error;
      }
      continue;
    }
    log('error fetching transactions from a relayer', result.reason);
    // The caller shows one warning, so the first failure is the one reported. The
    // transactions the other relayers did return are still handed back alongside it
    error ??= result.reason as Error;
  }

  // Flatten the arrays into a single array, dropping duplicate hashes the relayer
  // may return across pages or relayers
  const relayerTxsFlattened = relayerTxsArrays.reduce((acc, txs) => acc.concat(txs), []);
  const seenTxHashes = new Set<string>();
  const dedupedRelayerTxs = relayerTxsFlattened.filter((tx) => {
    if (seenTxHashes.has(tx.srcTxHash)) return false;
    seenTxHashes.add(tx.srcTxHash);
    return true;
  });

  // A transaction that failed on one page or relayer and loaded on another is not lost, so it
  // must not be reported as such. seenTxHashes is exactly the set that made it into the list.
  for (const hash of seenTxHashes) failedTxHashes.delete(hash);
  const failedCount = failedTxHashes.size;

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
