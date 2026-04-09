import { MessageStatus } from '$libs/bridge/types';

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
