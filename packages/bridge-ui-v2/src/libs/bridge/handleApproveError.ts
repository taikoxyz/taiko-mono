import { get } from 'svelte/store';
import { t } from 'svelte-i18n';
import { UserRejectedRequestError } from 'viem';

import { errorToast, warningToast } from '$components/NotificationToast';
import { ApproveError, InsufficientAllowanceError, NoAllowanceRequiredError } from '$libs/error';

export const handleApproveError = (error: Error) => {
  switch (true) {
    case error instanceof UserRejectedRequestError:
      warningToast(get(t)('bridge.errors.approve_rejected'));
      break;
    case error instanceof NoAllowanceRequiredError:
      errorToast(get(t)('bridge.errors.no_allowance_required'));
      break;
    case error instanceof InsufficientAllowanceError:
      errorToast(get(t)('bridge.errors.insufficient_allowance'));
      break;
    case error instanceof ApproveError:
      // TODO: see contract for all possible errors
      errorToast(get(t)('bridge.errors.approve_error'));
      break;
    default:
      errorToast(get(t)('bridge.errors.unknown_error'));
  }
};
