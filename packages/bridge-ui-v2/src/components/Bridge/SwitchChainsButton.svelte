<script lang="ts">
  import { switchNetwork } from '@wagmi/core';
  import { t } from 'svelte-i18n';
  import { SwitchChainError, UserRejectedRequestError } from 'viem';

  import { Icon } from '$components/Icon';
  import { warningToast } from '$components/NotificationToast';

  import { destNetwork } from './state';

  async function switchToDestChain() {
    if (!$destNetwork) return;

    try {
      await switchNetwork({ chainId: $destNetwork.id });
    } catch (err) {
      console.error(err);
      if (err instanceof SwitchChainError) {
        warningToast({title: $t('messages.network.pending')});
      } else if (err instanceof UserRejectedRequestError) {
        warningToast({title: $t('messages.network.rejected')});
      }
    }
  }
</script>

<button class="f-center rounded-full w-[30px] h-[30px]" disabled={!$destNetwork} on:click={switchToDestChain}>
  <Icon type="up-down" class="rotate-90" />
</button>
