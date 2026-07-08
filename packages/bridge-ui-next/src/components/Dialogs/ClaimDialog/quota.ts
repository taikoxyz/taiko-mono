// Ported from packages/bridge-ui/src/components/Dialogs/ClaimDialog/quota.ts
// (upstream commit e91ad7f5f). Framework-agnostic: React callers pass their
// state setter as `setClaiming`.
import { isClaimBlockedByQuota } from "$libs/bridge/checkQuota";
import type { BridgeTransaction } from "$libs/bridge/types";

import { isQuotaManagerOutOfQuotaError } from "./error";

type QuotaToastDeps = {
  showQuotaReachedToast: () => void;
  onQuotaCheckError?: (error: unknown) => void;
};

type ClaimWithQuotaGuardArgs = QuotaToastDeps & {
  bridgeTx: BridgeTransaction;
  claim: () => Promise<void>;
  setClaiming: (claiming: boolean) => void;
};

export async function showQuotaToastIfClaimIsBlocked(
  bridgeTx: BridgeTransaction,
  { showQuotaReachedToast, onQuotaCheckError }: QuotaToastDeps,
): Promise<boolean> {
  try {
    if (await isClaimBlockedByQuota(bridgeTx)) {
      showQuotaReachedToast();
      return true;
    }
  } catch (quotaError) {
    onQuotaCheckError?.(quotaError);
  }
  return false;
}

export async function showQuotaToastForClaimError(
  error: unknown,
  bridgeTx: BridgeTransaction,
  deps: QuotaToastDeps,
): Promise<boolean> {
  if (isQuotaManagerOutOfQuotaError(error)) {
    deps.showQuotaReachedToast();
    return true;
  }

  return showQuotaToastIfClaimIsBlocked(bridgeTx, deps);
}

export async function claimWithQuotaGuard({
  bridgeTx,
  claim,
  setClaiming,
  showQuotaReachedToast,
  onQuotaCheckError,
}: ClaimWithQuotaGuardArgs): Promise<void> {
  setClaiming(true);

  if (
    await showQuotaToastIfClaimIsBlocked(bridgeTx, {
      showQuotaReachedToast,
      onQuotaCheckError,
    })
  ) {
    setClaiming(false);
    return;
  }

  await claim();
}
