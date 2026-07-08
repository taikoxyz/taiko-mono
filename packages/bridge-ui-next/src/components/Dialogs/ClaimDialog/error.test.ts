import { describe, expect, it } from "vitest";

import {
  isMessageNotReceivedError,
  isQuotaManagerOutOfQuotaError,
} from "./error";

describe("isMessageNotReceivedError", () => {
  it("returns true for legacy and current bridge not received errors", () => {
    expect(
      isMessageNotReceivedError(
        new Error("execution reverted: B_NOT_RECEIVED()"),
      ),
    ).toBe(true);
    expect(
      isMessageNotReceivedError(
        new Error("execution reverted: B_SIGNAL_NOT_RECEIVED()"),
      ),
    ).toBe(true);
  });

  it("reads nested cause metadata when viem wraps the revert", () => {
    const wrappedError = {
      message: 'The contract function "processMessage" reverted.',
      cause: {
        shortMessage: "The contract function reverted.",
        data: {
          errorName: "B_SIGNAL_NOT_RECEIVED",
        },
      },
    };

    expect(isMessageNotReceivedError(wrappedError)).toBe(true);
  });

  it("returns false for unrelated failures", () => {
    expect(
      isMessageNotReceivedError(
        new Error("execution reverted: B_PERMISSION_DENIED()"),
      ),
    ).toBe(false);
  });
});

describe("isQuotaManagerOutOfQuotaError", () => {
  it("returns true when viem decodes the quota manager custom error name", () => {
    const wrappedError = {
      message: 'The contract function "processMessage" reverted.',
      cause: {
        shortMessage: "The contract function reverted.",
        data: {
          errorName: "QM_OUT_OF_QUOTA",
        },
      },
    };

    expect(isQuotaManagerOutOfQuotaError(wrappedError)).toBe(true);
  });

  it("returns true when viem cannot decode the custom error but includes its selector", () => {
    const wrappedError = {
      message: 'The contract function "processMessage" reverted.',
      cause: {
        shortMessage: 'Encoded error signature "0x51d8fe3a" not found on ABI.',
        data: "0x51d8fe3a",
      },
    };

    expect(isQuotaManagerOutOfQuotaError(wrappedError)).toBe(true);
  });

  it("returns true when viem exposes only the custom error signature field", () => {
    const wrappedError = {
      message: 'The contract function "processMessage" reverted.',
      cause: {
        signature: "0x51d8fe3a",
      },
    };

    expect(isQuotaManagerOutOfQuotaError(wrappedError)).toBe(true);
  });

  it("returns false when retryMessage wraps an invocation failure as B_RETRY_FAILED", () => {
    const wrappedError = {
      message: 'The contract function "retryMessage" reverted.',
      cause: {
        shortMessage:
          "The contract function reverted with the following signature: 0x161e3ead",
        data: {
          errorName: "B_RETRY_FAILED",
        },
      },
    };

    expect(isQuotaManagerOutOfQuotaError(wrappedError)).toBe(false);
  });

  it("returns false for unrelated quota manager errors", () => {
    expect(
      isQuotaManagerOutOfQuotaError(
        new Error("execution reverted: QM_INVALID_PARAM()"),
      ),
    ).toBe(false);
  });
});
