"use client";

import { TransactionExecutionError, UserRejectedRequestError } from "viem";

import { errorToast, warningToast } from "@/components/NotificationToast";
import {
  InsufficientAllowanceError,
  SendERC20Error,
  SendMessageError,
  TransactionTimeoutError,
} from "$libs/error";

import i18n from "@/i18n";

/**
 * Maps a bridge error to a toast notification.
 *
 * Ported from the original `handleBridgeErrors.ts`:
 *   - svelte-i18n `get(t)('key')` -> i18next standalone `i18n.t('key')`
 *     (callable outside React, matching the original render-less lookup).
 *   - Toasts render via the shared `$components/NotificationToast` helpers,
 *     exactly like the original: pixel-parity ItemToast chrome, and
 *     error/warning toasts stay open until manually dismissed.
 */

export const handleBridgeError = (error: Error) => {
  switch (true) {
    case error instanceof InsufficientAllowanceError:
      errorToast({
        title: i18n.t("bridge.errors.insufficient_allowance.title"),
        message: i18n.t("bridge.errors.insufficient_allowance.message"),
      });
      break;
    case error instanceof SendMessageError:
      // TODO: see contract for all possible errors
      errorToast({
        title: i18n.t("bridge.errors.send_message_error.title"),
        message: i18n.t("bridge.errors.send_message_error.message"),
      });
      break;
    case error instanceof SendERC20Error:
      // TODO: see contract for all possible errors
      errorToast({
        title: i18n.t("bridge.errors.send_erc20_error.title"),
        message: i18n.t("bridge.errors.send_erc20_error.message"),
      });
      break;
    case error instanceof UserRejectedRequestError:
      // Todo: viem does not seem to detect UserRejectError
      warningToast({
        title: i18n.t("bridge.errors.approve_rejected.title"),
      });
      break;
    case error instanceof TransactionExecutionError &&
      error.shortMessage === "User rejected the request.":
      //Todo: so we catch it by string comparison below, suboptimal
      warningToast({
        title: i18n.t("bridge.errors.approve_rejected.title"),
      });
      break;
    case error instanceof TransactionTimeoutError:
      warningToast({
        title: i18n.t("bridge.errors.transaction_timeout.title"),
        message: i18n.t("bridge.errors.transaction_timeout.message"),
      });
      break;
    default:
      errorToast({
        title: i18n.t("bridge.errors.unknown_error.title"),
        message: i18n.t("bridge.errors.unknown_error.message"),
      });
  }
};
