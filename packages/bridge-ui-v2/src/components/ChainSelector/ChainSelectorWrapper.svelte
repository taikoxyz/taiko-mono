<script lang="ts">
  import { onMount } from 'svelte';

  import { chainConfig } from '$chainConfig';
  import { destNetwork, destOptions } from '$components/Bridge/state';
  import SwitchChainsButton from '$components/Bridge/SwitchChainsButton.svelte';
  import { ChainSelector } from '$components/ChainSelector';
  import { OnNetwork } from '$components/OnNetwork';
  import { hasBridge } from '$libs/bridge/bridges';
  import { chainIdToChain, chains } from '$libs/chain';
  import { network } from '$stores/network';

  let destChainElement: ChainSelector;

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
    const alternateChainID = getAlternateNetwork();
    if (!$destNetwork && alternateChainID) {
      // if only two chains are available, set the destination chain to the other one
      $destNetwork = chainIdToChain(alternateChainID);
    }
  }

  const getAlternateNetwork = (): number | null => {
    if (!$network?.id) {
      return null;
    }
    const currentNetwork: number = Number($network.id);
    const chainKeys: number[] = Object.keys(chainConfig).map(Number);

    // only allow switching between two chains, if we have more we do not use this util
    if (chainKeys.length !== 2) {
      return null;
    }

    const alternateChainId = chainKeys.find((key) => key !== currentNetwork);
    if (!alternateChainId) return null;
    return alternateChainId;
  };

  onMount(() => {
    updateDestOptions();
  });
</script>

<ChainSelector class="flex-1" bind:value={$network} on:change={handleSourceChange} switchWallet />

<SwitchChainsButton />

<ChainSelector
  bind:this={destChainElement}
  class="flex-1 "
  bind:value={$destNetwork}
  on:change={handleDestChange}
  validOptions={$destOptions} />

<OnNetwork change={onNetworkChange} />
