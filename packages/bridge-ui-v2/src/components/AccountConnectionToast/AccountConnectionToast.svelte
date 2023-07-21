<script lang="ts">
  import { t } from 'svelte-i18n';

  import { successToast, warningToast } from '$components/NotificationToast';
  import { account } from '$stores/account';

  let prevAccount = $account;

  // Listen to changes in the account state and notify the user
  // when the account is connected or disconnected via toast
  account.subscribe((_account) => {
    if (_account?.isConnected) {
      successToast($t('messages.account.connected'));
    } else if (prevAccount && _account?.isDisconnected) {
      // We check if there was previous account, if not
      // the user just hit the app, and there is no need
      // to show the message.
      warningToast($t('messages.account.disconnected'));
    }

    prevAccount = _account;
  });
</script>
