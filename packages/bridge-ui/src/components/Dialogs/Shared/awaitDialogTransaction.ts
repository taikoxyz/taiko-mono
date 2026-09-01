import type { Hex } from 'viem';

import { TransactionTimeoutError } from '$libs/error';
import { pendingTransactions } from '$stores/pendingTransactions';

/**
 * How a dialog's transaction settled.
 *
 * `timed_out` is deliberately not folded into `failed`: only the receipt wait gave up, so
 * the transaction is still live and may yet do what the user asked. A dialog that treats
 * it as a failure hands back an enabled Claim/Retry/Release button for a message whose
 * first attempt is still in the mempool.
 */
export type DialogTransactionOutcome = 'confirmed' | 'timed_out' | 'failed';

/**
 * @dev Waits for a dialog's transaction and reports how the dialog should settle.
 * @param txHash The transaction to wait for
 * @param chainId The chain the transaction was sent on
 * @return outcome_ Whether the transaction confirmed, timed out, or failed
 */
export const awaitDialogTransaction = async (txHash: Hex, chainId: number): Promise<DialogTransactionOutcome> => {
  try {
    await pendingTransactions.add(txHash, chainId);
    return 'confirmed';
  } catch (error) {
    if (error instanceof TransactionTimeoutError) return 'timed_out';
    return 'failed';
  }
};
