<script lang="ts">
  import { switchNetwork } from '@wagmi/core';

  import { Icon } from '$components/Icon';

  import { destNetwork } from './state';
  import { UserRejectedRequestError } from 'viem';
  import { warningToast } from '$components/NotificationToast';
  import { t } from 'svelte-i18n';

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
