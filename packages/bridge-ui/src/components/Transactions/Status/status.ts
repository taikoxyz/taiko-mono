import { MessageStatus } from '$libs/bridge/types';
import { BridgePausedError } from '$libs/error';

type ManualClaimEntryArgs = {
  bridgeTxStatus?: MessageStatus | null;
  isProcessable: boolean;
  processingFee: bigint;
};

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
