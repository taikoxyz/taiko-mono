import type { Processability } from '$libs/bridge/isTransactionProcessable';
import type { BridgeTransaction } from '$libs/bridge/types';
import { MessageStatus } from '$libs/bridge/types';
import { BridgePausedError } from '$libs/error';

type ManualClaimEntryArgs = {
  bridgeTxStatus?: MessageStatus | null;
  isProcessable: Processability;
  processingFee: bigint;
};

// A locally stored transaction can legitimately lack a msgHash for a while (unmined tx, slow RPC
// during enhancement), so it may only be pruned from storage once it is old enough that the
// missing data cannot be transient anymore.
export const STALE_LOCAL_TX_MAX_AGE_MS = 24 * 60 * 60 * 1000;

export function isEligibleForStorageRemoval(tx: BridgeTransaction, now: number): boolean {
  if (tx.msgHash) return false;
  if (!tx.timestamp) return false;
  return now - tx.timestamp > STALE_LOCAL_TX_MAX_AGE_MS;
}

/**
 * Whether to offer a manual claim in place of the transaction's usual status.
 *
 * A message that pays no relayer fee will never be picked up for the user, so a row that can only
 * ever say "processing" is a dead end and this entry is the way out of it. It is offered only where
 * processability could not be established: a determinate `false` means the destination chain has
 * not synced the source block yet, and the claim started from it is one BridgeProver rejects with
 * BlockNotSyncedError. That case resolves itself with the next checkpoint, so the pending status is
 * both the honest thing to show and the one that does not send the user into a failing transaction.
 *
 * @param args The message status, its processability and the fee it offers a relayer
 * @return show_ Whether the manual claim entry should replace the status
 */
export function shouldShowManualClaimEntry({
  bridgeTxStatus,
  isProcessable,
  processingFee,
}: ManualClaimEntryArgs): boolean {
  return bridgeTxStatus === MessageStatus.NEW && isProcessable === null && processingFee === 0n;
}

export function assertBridgeNotPaused(isPaused: boolean): void {
  if (isPaused) {
    throw new BridgePausedError('Bridge is paused');
  }
}
