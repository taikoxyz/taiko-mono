import { get } from 'svelte/store';
import { t } from 'svelte-i18n';
import { SwitchChainError, UserRejectedRequestError } from 'viem';

import { warningToast } from '$components/NotificationToast';

export const handleSwitchChainError = (error: unknown): boolean => {
  if (error instanceof SwitchChainError) {
    warningToast({
      title: get(t)('messages.network.pending.title'),
      message: get(t)('messages.network.pending.message'),
    });
    return true;
  }

  if (error instanceof UserRejectedRequestError) {
    warningToast({
      title: get(t)('messages.network.rejected.title'),
      message: get(t)('messages.network.rejected.message'),
    });
    return true;
  }

  return false;
};
