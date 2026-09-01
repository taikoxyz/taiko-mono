import type { Hex } from 'viem';

import { FailedTransactionError } from '$libs/error';
import { pendingTransactions } from '$stores/pendingTransactions';

/**
 * How a dialog's transaction settled.
 *
 * `pending` is deliberately not folded into `failed`: it covers every outcome where the
 * *wait* gave up rather than the transaction - a receipt wait that timed out, an RPC that
 * dropped the connection - and the transaction is still live and may yet do what the user
 * asked. A dialog that treats those as failures hands back an enabled Claim/Retry/Release
 * button for a message whose first attempt is still in the mempool.
 *
 * Only a receipt that came back reverted is `failed`.
 */
export type DialogTransactionOutcome = 'confirmed' | 'pending' | 'failed';

/**
 * @dev Waits for a dialog's transaction and reports how the dialog should settle.
 * @param txHash The transaction to wait for
 * @param chainId The chain the transaction was sent on
 * @return outcome_ Whether the transaction confirmed, is still pending, or reverted
 */
export const awaitDialogTransaction = async (txHash: Hex, chainId: number): Promise<DialogTransactionOutcome> => {
  try {
    await pendingTransactions.add(txHash, chainId);
    return 'confirmed';
  } catch (error) {
    // Every other rejection - a timeout, an unreadable receipt, anything unrecognised -
    // leaves the transaction's fate unknown, and unknown is not failed
    return error instanceof FailedTransactionError ? 'failed' : 'pending';
  }
};
