<script lang="ts">
  import { switchChain } from '@wagmi/core';

  import { destNetwork } from '$components/Bridge/state';
  import { Icon } from '$components/Icon';
  import { handleSwitchChainError } from '$libs/network/handleSwitchChainError';
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
      handleSwitchChainError(err);
    }
  }
</script>

<button
  class="f-center rounded-full w-[30px] h-[30px]"
  disabled={!$destNetwork || disabled}
  on:click={switchToDestChain}>
  <Icon type="up-down" class="" size={16} />
</button>
