<script lang="ts">
  import { switchNetwork } from '@wagmi/core';
  import { t } from 'svelte-i18n';
  import { UserRejectedRequestError } from 'viem';

  import { Icon } from '$components/Icon';
  import { warningToast } from '$components/NotificationToast';

  import { destNetwork } from './state';

  async function switchToDestChain() {
    if (!$destNetwork) return;

    try {
      await switchNetwork({ chainId: $destNetwork.id });
    } catch (err) {
      console.error(err);

      if (err instanceof UserRejectedRequestError) {
        warningToast($t('messages.network.rejected'));
      }
    }
  }
</script>

<button
  class="f-center rounded-full bg-secondary-icon w-[30px] h-[30px]"
  disabled={!$destNetwork}
  on:click={switchToDestChain}>
  <Icon type="up-down" />
</button>
