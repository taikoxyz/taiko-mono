<script lang="ts">
  import { onMount } from 'svelte';

  import { destNetwork, destOptions } from '$components/Bridge/state';
  import SwitchChainsButton from '$components/Bridge/SwitchChainsButton.svelte';
  import { ChainSelector } from '$components/ChainSelector';
  import { OnNetwork } from '$components/OnNetwork';
  import { hasBridge } from '$libs/bridge/bridges';
  import { chains } from '$libs/chain';
  import { network } from '$stores/network';

  function handleSourceChange(): void {
    updateDestOptions();
  }

  function handleDestChange(): void {
    updateDestOptions();
  }

  function updateDestOptions() {
    $destOptions = chains.filter((chain) => {
      const excludeCurrentSrc = chain.id !== $network?.id;
      const hasBridgeCondition = $network?.id === null || ($network?.id && hasBridge($network?.id, chain.id));

      return excludeCurrentSrc && hasBridgeCondition;
    });
  }

  function onNetworkChange() {
    updateDestOptions();
  }

  onMount(() => {
    updateDestOptions();
  });
</script>

<ChainSelector class="flex-1" bind:value={$network} on:change={handleSourceChange} switchWallet />

<SwitchChainsButton />

<ChainSelector class="flex-1" bind:value={$destNetwork} on:change={handleDestChange} validOptions={$destOptions} />

<OnNetwork change={onNetworkChange} />
