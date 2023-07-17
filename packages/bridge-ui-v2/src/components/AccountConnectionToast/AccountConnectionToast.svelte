<script lang="ts">
  import { t } from 'svelte-i18n';

  import { successToast, warningToast } from '$components/NotificationToast';
  import { OnAccount } from '$components/OnAccount';
  import type { Account } from '$stores/account';

  // Listen to changes in the account state and notify the user
  // when the account is connected or disconnected via toast
  function onAccountChange(newAccount: Account, oldAccount?: Account) {
    if (newAccount?.isConnected) {
      successToast($t('messages.account.connected'));
    } else if (oldAccount && newAccount?.isDisconnected) {
      // We check if there was previous account, if not
      // the user just hit the app, and there is no need
      // to show the message.
      warningToast($t('messages.account.disconnected'));
    }
  }
</script>

<OnAccount change={onAccountChange} />
