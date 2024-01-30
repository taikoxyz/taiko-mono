<script lang="ts">
  import { onMount } from 'svelte';
  import { t } from 'svelte-i18n';

  import { chainConfig } from '$chainConfig';
  import { destNetwork, destOptions } from '$components/Bridge/state';
  import SwitchChainsButton from '$components/Bridge/SwitchChainsButton.svelte';
  import { ChainSelector } from '$components/ChainSelector';
  import { OnAccount } from '$components/OnAccount';
  import { OnNetwork } from '$components/OnNetwork';
  import { hasBridge } from '$libs/bridge/bridges';
  import { chainIdToChain, chains } from '$libs/chain';
  import { account } from '$stores/account';
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

  const getAlternateNetwork = (): number | null => {
    if (!$network?.id) {
      return null;
    }
    const currentNetwork: number = Number($network.id);
    const chainKeys: number[] = Object.keys(chainConfig).map(Number);

    // only allow switching between two chains, if we have more we do not use this util
    if (chainKeys.length !== 2) {
      updateDestOptions();
      return null;
    }

    const alternateChainId = chainKeys.find((key) => key !== currentNetwork);
    if (!alternateChainId) return null;
    updateDestOptions();
    return alternateChainId;
  };

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
