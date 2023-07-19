<script lang="ts">
  import { switchNetwork } from '@wagmi/core';

  import { Icon } from '$components/Icon';

  import { destNetwork } from './state';

  async function switchToDestChain() {
    if (!$destNetwork) return;

    await switchNetwork({ chainId: $destNetwork.id });
  }
</script>

<button
  class="f-center rounded-full bg-secondary-icon w-[30px] h-[30px]"
  disabled={!$destNetwork}
  on:click={switchToDestChain}>
  <Icon type="up-down" />
</button>
