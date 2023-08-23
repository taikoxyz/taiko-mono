<script lang="ts">
  import { chains, hasBridge } from '$libs/chain';
  import { writable } from 'svelte/store';
  import ChainSelector from './ChainSelector.svelte';
  import { network, type Network } from '$stores/network';
  import { destNetwork } from '$components/Bridge/state';
  import SwitchChainsButton from '$components/Bridge/SwitchChainsButton.svelte';
  import { OnNetwork } from '$components/OnNetwork';

  //   const sourceOptions = writable(chains);
  const destOptions = writable(chains);

  function handleSourceChange(event: CustomEvent<number>): void {
    updateDestOptions();
  }

  function handleDestChange(event: CustomEvent<number>): void {
    updateDestOptions();
  }

  function updateDestOptions() {
    destOptions.set(
      chains.filter((chain) => {
        console.log(`dest check: chain.id: ${chain.id}, srcChain: ${$network?.id}`);
        const excludeCurrentSrc = chain.id !== $network?.id;
        const hasBridgeCondition = $network?.id === null || ($network?.id && hasBridge($network?.id, chain.id));

        console.log(
          `destOptions - chain.id: ${chain.id}, excludeCurrentSrc: ${excludeCurrentSrc}, hasBridgeCondition: ${hasBridgeCondition}`,
        );

        return excludeCurrentSrc && hasBridgeCondition;
      }),
    );
    console.log('destOptions', $destOptions);
  }

  function onNetworkChange(newNetwork: Network, oldNetwork: Network) {
    updateDestOptions();
  }
</script>

<ChainSelector class="flex-1" bind:value={$network} on:change={handleSourceChange} switchWallet />

<SwitchChainsButton />

<ChainSelector class="flex-1" bind:value={$destNetwork} on:change={handleDestChange} validOptions={$destOptions} />

<OnNetwork change={onNetworkChange} />
