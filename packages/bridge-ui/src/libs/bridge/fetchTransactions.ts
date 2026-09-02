import type { Address } from 'viem';

import { RelayerHistoryTruncatedError } from '$libs/error';
import type { FailedBridgeTx } from '$libs/relayer';
import { relayerApiServices } from '$libs/relayer';
import { bridgeTxService } from '$libs/storage';
import { getLogger } from '$libs/util/logger';
import { mergeAndCaptureOutdatedTransactions } from '$libs/util/mergeTransactions';

import { bridgeTxKey, isSameBridgeTx } from './bridgeTxIdentity';
import { type BridgeTransaction, MessageStatus } from './types';

const log = getLogger('bridge:fetchTransactions');

const RELAYER_PAGE_SIZE = 500;
// Backstop against unbounded relayer histories; each page is one API call
const MAX_RELAYER_PAGES = 10;

async function fetchAllRelayerPages(
  relayerApiService: (typeof relayerApiServices)[number],
  userAddress: Address,
  chainId?: number,
): Promise<{ txs: BridgeTransaction[]; failedTxs: FailedBridgeTx[]; error?: Error }> {
  const txs: BridgeTransaction[] = [];
  const failedTxs: FailedBridgeTx[] = [];

  for (let page = 0; page < MAX_RELAYER_PAGES; page++) {
    let pageTxs;
    let paginationInfo;
    let pageFailedTxs;
    try {
      ({
        txs: pageTxs,
        paginationInfo,
        failedTxs: pageFailedTxs,
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
      // failedTxs carries what the completed pages already lost to failed on-chain reads.
      return { txs, failedTxs, error: error as Error };
    }
    txs.push(...pageTxs);
    failedTxs.push(...pageFailedTxs);

    if (paginationInfo.max_page === undefined || page >= paginationInfo.max_page) break;
    if (page === MAX_RELAYER_PAGES - 1) {
      // Same rule as a failed page: degrading is fine, degrading in silence is not. A
      // history cut off at the backstop looks exactly like a complete one.
      log(`relayer history truncated at ${MAX_RELAYER_PAGES} pages for ${userAddress}`);
      return {
        txs,
        failedTxs,
        error: new RelayerHistoryTruncatedError(
          `Relayer history truncated at ${MAX_RELAYER_PAGES} pages; older transactions are not shown`,
        ),
      };
    }
  }
  return { txs, failedTxs };
}

export async function fetchTransactions(userAddress: Address, chainId?: number) {
  // Scoped per call: a module-level variable would keep reporting "relayer offline" on
  // every later, successful fetch. Collected rather than kept-first, see below.
  const errors: Error[] = [];

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
  // Keyed by message identity so the same failure arriving from two pages or two relayers is
  // held once
  const failedByKey = new Map<string, FailedBridgeTx>();
  for (const result of relayerResults) {
    if (result.status === 'fulfilled') {
      relayerTxsArrays.push(result.value.txs);
      for (const failed of result.value.failedTxs) failedByKey.set(bridgeTxKey(failed), failed);
      // A relayer that answered some pages and then failed still reports that failure,
      // so a partial history is not presented as a complete one
      if (result.value.error) {
        log('a relayer stopped part-way through its pages', result.value.error);
        errors.push(result.value.error);
      }
      continue;
    }
    log('error fetching transactions from a relayer', result.reason);
    // The transactions the other relayers did return are still handed back alongside it
    errors.push(result.reason as Error);
  }

  // One warning is shown, so one error is reported - but not simply the first. A truncated
  // history is the mildest thing a relayer can report, and keeping it because relayer A
  // happened to answer first hid relayer B rejecting outright: the user was told their
  // history was too long while B's transactions were silently absent.
  const error = errors.find((candidate) => !(candidate instanceof RelayerHistoryTruncatedError)) ?? errors[0];

  // Flatten the arrays into a single array, dropping messages the relayer may return
  // twice across pages or relayers. Keyed by message, not by transaction: a transaction
  // that emitted two messages has two claimable rows, and the second was being dropped
  const relayerTxsFlattened = relayerTxsArrays.reduce((acc, txs) => acc.concat(txs), []);
  const seenMessages = new Set<string>();
  const dedupedRelayerTxs = relayerTxsFlattened.filter((tx) => {
    const key = bridgeTxKey(tx);
    if (seenMessages.has(key)) return false;
    seenMessages.add(key);
    return true;
  });

  // Reverse the flattened array to sort transactions in descending order, placing the most recent transactions first
  const relayerTxs: BridgeTransaction[] = dedupedRelayerTxs.reverse();

  log(`fetched ${relayerTxs?.length ?? 0} transactions from all relayers`, relayerTxs);

  const { mergedTransactions, outdatedLocalTransactions } = mergeAndCaptureOutdatedTransactions(localTxs, relayerTxs);

  // The count answers "how many of your messages are missing from this list", so it is taken
  // against the finished list rather than the relayer half of it. A message can reach the list by
  // a route other than the one that failed: another page or relayer returned it, or - because the
  // merge keeps a local transaction precisely when the relayer set lacks it - the row came from
  // local storage. Counting those would tell the user something is missing while it is on screen.
  //
  // Compared with isSameBridgeTx rather than by transaction hash, because the two sides are not
  // identified the same way: a failed relayer row knows its message hash while the local row that
  // rescues it usually does not.
  //
  // Each row rescues at most one failure. That only matters for the transaction-hash fallback,
  // which is ambiguous: a local row carries no message hash, so it cannot tell which of several
  // messages from its transaction it stands for - and it stands for one of them, not all. Exact
  // message matches are one-to-one anyway, so consuming them changes nothing there.
  const unrescued = [...failedByKey.values()];
  for (const tx of mergedTransactions) {
    const rescued = unrescued.findIndex((failed) => isSameBridgeTx(failed, tx));
    if (rescued !== -1) unrescued.splice(rescued, 1);
  }
  const failedCount = unrescued.length;

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
