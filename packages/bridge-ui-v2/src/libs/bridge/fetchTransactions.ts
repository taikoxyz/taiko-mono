import type { Address } from 'viem';

import { relayerApiService } from '$libs/relayer';
import { bridgeTxService } from '$libs/storage';
import { getLogger } from '$libs/util/logger';
import { mergeUniqueTransactions } from '$libs/util/mergeTransactions';

import type { BridgeTransaction } from './types';

const log = getLogger('bridge:fetchTransactions');

export async function fetchTransactions(userAddress: Address) {
  // Transactions from local storage
  const localTxs: BridgeTransaction[] = await bridgeTxService.getAllTxByAddress(userAddress);

  // Transactions from relayer
  const { txs } = await relayerApiService.getAllBridgeTransactionByAddress(userAddress, {
    page: 0,
    size: 100,
  });

  const transactions = mergeUniqueTransactions(localTxs, txs);

  log(`merging ${localTxs.length} local and ${txs.length} relayer transactions. New size: ${transactions.length}`);

  return transactions;
}
