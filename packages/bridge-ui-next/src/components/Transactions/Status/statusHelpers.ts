// Ported verbatim from
// components/Transactions/Status/status.ts.
//
// Pure logic helpers (no Svelte/React specifics): `shouldShowManualClaimEntry`
// decides whether to surface the manual-claim ("Try claim") entry point, and
// `assertBridgeNotPaused` throws when the bridge is paused. Imports remapped to
// the Next.js aliases (`@/libs/bridge/types`, `@/libs/error`).
import { MessageStatus } from "@/libs/bridge/types";
import { BridgePausedError } from "@/libs/error";

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
  return (
    bridgeTxStatus === MessageStatus.NEW &&
    !isProcessable &&
    processingFee === 0n
  );
}

export function assertBridgeNotPaused(isPaused: boolean): void {
  if (isPaused) {
    throw new BridgePausedError("Bridge is paused");
  }
}
