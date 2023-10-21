import { get } from 'svelte/store';
import { t } from 'svelte-i18n';
import { TransactionExecutionError, UserRejectedRequestError } from 'viem';

import { errorToast, warningToast } from '$components/NotificationToast';
import { InsufficientAllowanceError, SendERC20Error, SendMessageError } from '$libs/error';

export const handleBridgeError = (error: Error) => {
  switch (true) {
    case error instanceof InsufficientAllowanceError:
      errorToast(get(t)('bridge.errors.insufficient_allowance'));
      break;
    case error instanceof SendMessageError:
      // TODO: see contract for all possible errors
      errorToast(get(t)('bridge.errors.send_message_error'));
      break;
    case error instanceof SendERC20Error:
      // TODO: see contract for all possible errors
      errorToast(get(t)('bridge.errors.send_erc20_error'));
      break;
    case error instanceof UserRejectedRequestError:
      // Todo: viem does not seem to detect UserRejectError
      warningToast(get(t)('bridge.errors.approve_rejected'));
      break;
    case error instanceof TransactionExecutionError && error.shortMessage === 'User rejected the request.':
      //Todo: so we catch it by string comparison below, suboptimal
      warningToast(get(t)('bridge.errors.approve_rejected'));
      break;
    default:
      errorToast(get(t)('bridge.errors.unknown_error'));
  }
};
