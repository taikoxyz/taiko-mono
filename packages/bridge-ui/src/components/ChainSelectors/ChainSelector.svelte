<script lang="ts">
  import { switchChain } from '@wagmi/core';
  import { type Chain } from 'viem';

  import { destNetwork } from '$components/Bridge/state';
  import { OnAccount } from '$components/OnAccount';
  import { OnNetwork } from '$components/OnNetwork';
  import { handleSwitchChainError } from '$libs/network/handleSwitchChainError';
  import { setAlternateNetwork } from '$libs/network/setAlternateNetwork';
  import { config } from '$libs/wagmi';
  import { connectedSourceChain, switchingNetwork } from '$stores/network';

  import ChainPill from './ChainPill/ChainPill.svelte';
  import CombinedChainSelector from './CombinedChainSelector/CombinedChainSelector.svelte';
  import { ChainSelectorDirection, ChainSelectorType } from './types';

  export let type: ChainSelectorType;
  export let direction: ChainSelectorDirection = ChainSelectorDirection.BOTH;
  export let label: string = '';

  export let switchWallet = false;

  async function selectChain(event: CustomEvent<{ chain: Chain; switchWallet: boolean }>) {
    const { chain: selectedChain, switchWallet } = event.detail;
    const currentChain = $connectedSourceChain;

    if (switchWallet && currentChain) {
      $switchingNetwork = true;
      try {
        await switchChain(config, { chainId: selectedChain.id });
        if (currentChain && selectedChain.id === currentChain.id) {
          // swap the chains
          destNetwork.set(currentChain);
        } else {
          setAlternateNetwork();
        }
      } catch (err) {
        if (!handleSwitchChainError(err)) {
          console.error(err);
        }
      } finally {
        $switchingNetwork = false;
      }
    } else {
      $destNetwork = selectedChain;
    }
  }

  const onNetworkChange = () => setAlternateNetwork();

  const onAccountChange = () => setAlternateNetwork();

  $: pillValue =
    direction === ChainSelectorDirection.SOURCE
      ? $connectedSourceChain
      : direction === ChainSelectorDirection.DESTINATION
        ? $destNetwork
        : null; // invalid state for pill, must be either source or destination
</script>

{#if type === ChainSelectorType.COMBINED}
  <CombinedChainSelector {selectChain} />
{:else if type === ChainSelectorType.SMALL}
  <ChainPill {label} value={pillValue} {selectChain} {switchWallet} />
{/if}

<OnNetwork change={onNetworkChange} />
<OnAccount change={onAccountChange} />
