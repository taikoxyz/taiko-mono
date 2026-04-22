<script lang="ts">
  import { t } from 'svelte-i18n';

  import type { Account } from '../../stores/account';
  import { successToast, warningToast } from '../core/Toast';
  import { OnAccount } from '../OnAccount';

  // Listen to changes in the account state and notify the user
  // when the account is connected or disconnected via toast
  function onAccountChange(newAccount: Account, oldAccount?: Account) {
    if (newAccount?.isConnected) {
      if (newAccount.chain === oldAccount?.chain) {
        // if the chain stays the same, we switched accounts
        successToast({ title: $t('messages.account.connected') });
      } else {
        // otherwise we switched chains
        successToast({
          title: $t('messages.network.success.title'),
          message: $t('messages.network.success.message', {
            values: { chainName: newAccount.chain?.name },
          }),
        });
      }
    } else if (oldAccount && newAccount?.isDisconnected) {
      // We check if there was previous account, if not
      // the user just hit the app, and there is no need
      // to show the message.
      warningToast({ title: $t('messages.account.disconnected') });
    }
  }
</script>

<OnAccount change={onAccountChange} />
