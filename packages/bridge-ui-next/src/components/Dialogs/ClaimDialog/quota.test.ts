// Ported from packages/bridge-ui/src/components/Dialogs/ClaimDialog/quota.test.ts
// (upstream commit e91ad7f5f).
import { zeroAddress } from "viem";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { isClaimBlockedByQuota } from "$libs/bridge/checkQuota";
import type { BridgeTransaction } from "$libs/bridge/types";
import { TokenType } from "$libs/token/types";
import { ALICE, MOCK_MESSAGE_L2_L1 } from "$mocks";

import { claimWithQuotaGuard, showQuotaToastForClaimError } from "./quota";

vi.mock("$libs/bridge/checkQuota", () => ({
  isClaimBlockedByQuota: vi.fn(),
}));

const TOKEN = "0xA0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";

function bridgeTx(
  overrides: Partial<BridgeTransaction> = {},
): BridgeTransaction {
  return {
    srcTxHash: zeroAddress,
    msgHash: zeroAddress,
    processingFee: 0n,
    from: ALICE,
    amount: 100n,
    symbol: "USDC",
    srcChainId: 21n,
    destChainId: 1n,
    tokenType: TokenType.ERC20,
    canonicalTokenAddress: TOKEN,
    message: MOCK_MESSAGE_L2_L1,
    ...overrides,
  } as BridgeTransaction;
}

describe("claimWithQuotaGuard", () => {
  beforeEach(() => {
    vi.mocked(isClaimBlockedByQuota).mockReset();
  });

  it("shows the quota toast and skips submitting when quota is exhausted", async () => {
    vi.mocked(isClaimBlockedByQuota).mockResolvedValue(true);
    const claim = vi.fn();
    const showQuotaReachedToast = vi.fn();
    const setClaiming = vi.fn();

    await claimWithQuotaGuard({
      bridgeTx: bridgeTx(),
      claim,
      setClaiming,
      showQuotaReachedToast,
    });

    expect(setClaiming).toHaveBeenNthCalledWith(1, true);
    expect(setClaiming).toHaveBeenNthCalledWith(2, false);
    expect(showQuotaReachedToast).toHaveBeenCalledOnce();
    expect(claim).not.toHaveBeenCalled();
  });

  it("submits the claim when quota is available", async () => {
    vi.mocked(isClaimBlockedByQuota).mockResolvedValue(false);
    const claim = vi.fn().mockResolvedValue(undefined);
    const showQuotaReachedToast = vi.fn();
    const setClaiming = vi.fn();

    await claimWithQuotaGuard({
      bridgeTx: bridgeTx(),
      claim,
      setClaiming,
      showQuotaReachedToast,
    });

    expect(setClaiming).toHaveBeenCalledOnce();
    expect(setClaiming).toHaveBeenCalledWith(true);
    expect(showQuotaReachedToast).not.toHaveBeenCalled();
    expect(claim).toHaveBeenCalledOnce();
  });

  it("continues to submit when the proactive quota read fails", async () => {
    const quotaError = new Error("quota rpc unavailable");
    vi.mocked(isClaimBlockedByQuota).mockRejectedValue(quotaError);
    const claim = vi.fn().mockResolvedValue(undefined);
    const onQuotaCheckError = vi.fn();

    await claimWithQuotaGuard({
      bridgeTx: bridgeTx(),
      claim,
      setClaiming: vi.fn(),
      showQuotaReachedToast: vi.fn(),
      onQuotaCheckError,
    });

    expect(onQuotaCheckError).toHaveBeenCalledWith(quotaError);
    expect(claim).toHaveBeenCalledOnce();
  });
});

describe("showQuotaToastForClaimError", () => {
  beforeEach(() => {
    vi.mocked(isClaimBlockedByQuota).mockReset();
  });

  it("surfaces directly decoded quota errors without another quota read", async () => {
    const showQuotaReachedToast = vi.fn();
    const quotaError = { cause: { data: { errorName: "QM_OUT_OF_QUOTA" } } };

    await expect(
      showQuotaToastForClaimError(quotaError, bridgeTx(), {
        showQuotaReachedToast,
      }),
    ).resolves.toBe(true);

    expect(showQuotaReachedToast).toHaveBeenCalledOnce();
    expect(isClaimBlockedByQuota).not.toHaveBeenCalled();
  });

  it("surfaces wrapped retry failures when quota is currently exhausted", async () => {
    vi.mocked(isClaimBlockedByQuota).mockResolvedValue(true);
    const showQuotaReachedToast = vi.fn();
    const retryError = { cause: { data: { errorName: "B_RETRY_FAILED" } } };

    await expect(
      showQuotaToastForClaimError(retryError, bridgeTx(), {
        showQuotaReachedToast,
      }),
    ).resolves.toBe(true);

    expect(showQuotaReachedToast).toHaveBeenCalledOnce();
  });

  it("returns false for non-quota errors when quota is available", async () => {
    vi.mocked(isClaimBlockedByQuota).mockResolvedValue(false);
    const showQuotaReachedToast = vi.fn();

    await expect(
      showQuotaToastForClaimError(new Error("different error"), bridgeTx(), {
        showQuotaReachedToast,
      }),
    ).resolves.toBe(false);

    expect(showQuotaReachedToast).not.toHaveBeenCalled();
  });
});
