import { UserRejectedRequestError } from "viem";
import { beforeEach, describe, expect, it, vi } from "vitest";

const { errorToastMock, warningToastMock } = vi.hoisted(() => ({
  errorToastMock: vi.fn(),
  warningToastMock: vi.fn(),
}));

vi.mock("@/components/NotificationToast", () => ({
  errorToast: errorToastMock,
  warningToast: warningToastMock,
}));
vi.mock("@/i18n", () => ({
  default: { t: (key: string) => key },
}));

import { SendMessageError } from "$libs/error";

import { handleBridgeError } from "./handleBridgeErrors";

// Bridge failures must render through the shared NotificationToast helpers:
// they use the pixel-parity ItemToast chrome and error/warning toasts stay
// open until dismissed (bare sonner toasts auto-dismiss, so users can miss
// why their bridge transaction failed).
describe("handleBridgeError", () => {
  beforeEach(() => {
    errorToastMock.mockClear();
    warningToastMock.mockClear();
  });

  it("routes bridge errors through the shared errorToast", () => {
    handleBridgeError(new SendMessageError("failed to send"));

    expect(errorToastMock).toHaveBeenCalledTimes(1);
    expect(errorToastMock).toHaveBeenCalledWith(
      expect.objectContaining({
        title: "bridge.errors.send_message_error.title",
        message: "bridge.errors.send_message_error.message",
      }),
    );
  });

  it("routes user rejections through the shared warningToast", () => {
    handleBridgeError(new UserRejectedRequestError(new Error("rejected")));

    expect(warningToastMock).toHaveBeenCalledTimes(1);
    expect(warningToastMock).toHaveBeenCalledWith(
      expect.objectContaining({
        title: "bridge.errors.approve_rejected.title",
      }),
    );
  });

  it("falls back to the shared errorToast for unknown errors", () => {
    handleBridgeError(new Error("mystery"));

    expect(errorToastMock).toHaveBeenCalledWith(
      expect.objectContaining({
        title: "bridge.errors.unknown_error.title",
      }),
    );
  });
});
