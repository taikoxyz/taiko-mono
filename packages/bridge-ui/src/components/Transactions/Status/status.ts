import type { BridgeTransaction } from '$libs/bridge/types';
import { MessageStatus } from '$libs/bridge/types';
import { BridgePausedError } from '$libs/error';

type ManualClaimEntryArgs = {
  bridgeTxStatus?: MessageStatus | null;
  isProcessable: boolean;
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

export function shouldShowManualClaimEntry({
  bridgeTxStatus,
  isProcessable,
  processingFee,
}: ManualClaimEntryArgs): boolean {
  return bridgeTxStatus === MessageStatus.NEW && !isProcessable && processingFee === 0n;
}

export function assertBridgeNotPaused(isPaused: boolean): void {
  if (isPaused) {
    throw new BridgePausedError('Bridge is paused');
  }
}
