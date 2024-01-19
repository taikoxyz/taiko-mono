<script lang="ts">
  import { onMount } from 'svelte';
  import { t } from 'svelte-i18n';

  import { destNetwork, destOptions } from '$components/Bridge/state';
  import SwitchChainsButton from '$components/Bridge/SwitchChainsButton.svelte';
  import { ChainSelector } from '$components/ChainSelector';
  import { OnAccount } from '$components/OnAccount';
  import { OnNetwork } from '$components/OnNetwork';
  import { hasBridge } from '$libs/bridge/bridges';
  import { chainIdToChain, chains } from '$libs/chain';
  import { getAlternateNetwork } from '$libs/network';
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
    if (!$destNetwork && alternateChainID !== null) {
      // if only two chains are available, set the destination chain to the other one
      $destNetwork = chainIdToChain(alternateChainID);
    }
  }

  $: highlight = $destNetwork ? false : true;

  const onNetworkChange = () => setAlternateNetwork();

  const onAccountChange = () => setAlternateNetwork();

  const setAlternateNetwork = () => {
    if ($account && ($account.isConnected || $account.isConnecting)) {
      const alternateChainID = getAlternateNetwork();
      if (alternateChainID) {
        $destNetwork = chainIdToChain(alternateChainID);
      }
    } else {
      $destNetwork = null;
    }
  };

  onMount(() => {
    setAlternateNetwork();
  });
</script>

<ChainSelector
  class="flex-1"
  bind:value={$network}
  on:change={handleSourceChange}
  switchWallet
  fromToLabel={$t('common.from')} />

<SwitchChainsButton />

<ChainSelector
  bind:this={destChainElement}
  class="flex-1 "
  bind:value={$destNetwork}
  on:change={handleDestChange}
  validOptions={$destOptions}
  bind:highlight
  fromToLabel={$t('common.to')} />

<OnNetwork change={onNetworkChange} />
<OnAccount change={onAccountChange} />
