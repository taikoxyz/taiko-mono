<script lang="ts">
  import { destNetwork, destOptions } from '$components/Bridge/state';
  import SwitchChainsButton from '$components/Bridge/SwitchChainsButton.svelte';
  import { OnNetwork } from '$components/OnNetwork';
  import { hasBridge } from '$libs/bridge/bridges';
  import { chains } from '$libs/chain';
  import { type Network, network } from '$stores/network';

  import { ChainSelector } from '$components/ChainSelector';

  function handleSourceChange(event: CustomEvent<number>): void {
    updateDestOptions();
  }

  function handleDestChange(event: CustomEvent<number>): void {
    updateDestOptions();
  }

  function updateDestOptions() {
    $destOptions = chains.filter((chain) => {
      const excludeCurrentSrc = chain.id !== $network?.id;
      const hasBridgeCondition = $network?.id === null || ($network?.id && hasBridge($network?.id, chain.id));

      return excludeCurrentSrc && hasBridgeCondition;
    });
  }

  function onNetworkChange(newNetwork: Network, oldNetwork: Network) {
    updateDestOptions();
  }
</script>

<ChainSelector class="flex-1" bind:value={$network} on:change={handleSourceChange} switchWallet />

<SwitchChainsButton />

<ChainSelector class="flex-1" bind:value={$destNetwork} on:change={handleDestChange} validOptions={$destOptions} />

<OnNetwork change={onNetworkChange} />
