<script lang="ts">
  import { switchChain } from '@wagmi/core';
  import { t } from 'svelte-i18n';
  import { SwitchChainError, UserRejectedRequestError } from 'viem';

  import { destNetwork } from '$components/Bridge/state';
  import { Icon } from '$components/Icon';
  import { warningToast } from '$components/NotificationToast';
  import { setAlternateNetwork } from '$libs/network/setAlternateNetwork';
  import { config } from '$libs/wagmi';

  export let disabled = false;

  async function switchToDestChain() {
    if (!$destNetwork) return;

    try {
      await switchChain(config, { chainId: $destNetwork.id });
      setAlternateNetwork();
    } catch (err) {
      console.error(err);
      if (err instanceof SwitchChainError) {
        warningToast({ title: $t('messages.network.pending.title'), message: $t('messages.network.pending.message') });
      } else if (err instanceof UserRejectedRequestError) {
        warningToast({
          title: $t('messages.network.rejected.title'),
          message: $t('messages.network.rejected.message'),
        });
      }
    }
  }
</script>

<button
  class="f-center rounded-full w-[30px] h-[30px]"
  disabled={!$destNetwork || disabled}
  on:click={switchToDestChain}>
  <Icon type="up-down" class="" size={16} />
</button>
