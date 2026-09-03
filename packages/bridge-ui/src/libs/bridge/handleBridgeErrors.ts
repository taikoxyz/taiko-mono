import { get } from 'svelte/store';
import { t } from 'svelte-i18n';
import { TransactionExecutionError, UserRejectedRequestError } from 'viem';

import { errorToast, warningToast } from '$components/NotificationToast';
import {
  BridgePausedError,
  InsufficientAllowanceError,
  InvalidMessageError,
  SendERC20Error,
  SendMessageError,
  TransactionTimeoutError,
} from '$libs/error';

export const handleBridgeError = (error: Error) => {
  switch (true) {
    case error instanceof InsufficientAllowanceError:
      errorToast({
        title: get(t)('bridge.errors.insufficient_allowance.title'),
        message: get(t)('bridge.errors.insufficient_allowance.message'),
      });
      break;
    case error instanceof SendMessageError:
      // TODO: see contract for all possible errors
      errorToast({
        title: get(t)('bridge.errors.send_message_error.title'),
        message: get(t)('bridge.errors.send_message_error.message'),
      });
      break;
    case error instanceof SendERC20Error:
      // TODO: see contract for all possible errors
      errorToast({
        title: get(t)('bridge.errors.send_erc20_error.title'),
        message: get(t)('bridge.errors.send_erc20_error.message'),
      });
      break;
    case error instanceof UserRejectedRequestError:
      // Todo: viem does not seem to detect UserRejectError
      warningToast({
        title: get(t)('bridge.errors.approve_rejected.title'),
      });
      break;
    case error instanceof TransactionExecutionError && error.shortMessage === 'User rejected the request.':
      //Todo: so we catch it by string comparison below, suboptimal
      warningToast({
        title: get(t)('bridge.errors.approve_rejected.title'),
      });
      break;
    case error instanceof TransactionTimeoutError:
      warningToast({
        title: get(t)('bridge.errors.transaction_timeout.title'),
        message: get(t)('bridge.errors.transaction_timeout.message'),
      });
      break;
    // Both are raised before anything is signed - prepareSend refuses a paused bridge and
    // assertNoViolations refuses a message the contract would reject - and both used to land
    // on "unknown error", discarding a diagnosis the send path had just gone to the trouble
    // of making
    case error instanceof BridgePausedError:
      warningToast({
        title: get(t)('bridge.errors.bridge_paused.title'),
        message: get(t)('bridge.errors.bridge_paused.message'),
      });
      break;
    case error instanceof InvalidMessageError:
      errorToast({
        title: get(t)('bridge.errors.invalid_message.title'),
        message: get(t)('bridge.errors.invalid_message.message'),
      });
      break;
    default:
      errorToast({
        title: get(t)('bridge.errors.unknown_error.title'),
        message: get(t)('bridge.errors.unknown_error.message'),
      });
  }
};
