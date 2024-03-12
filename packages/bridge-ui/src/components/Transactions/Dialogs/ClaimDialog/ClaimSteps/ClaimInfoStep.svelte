<script lang="ts">
  import { switchChain } from '@wagmi/core';

  import { ActionButton } from '$components/Button';
  import type { BridgeTransaction } from '$libs/bridge';
  import { getChainName } from '$libs/chain';
  import { config } from '$libs/wagmi';
  import { connectedSourceChain, switchingNetwork } from '$stores/network';
  export let tx: BridgeTransaction;

  export let canContinue = false;

  $: txDestChainName = getChainName(Number(tx.destChainId));

  $: correctChain = Number(tx.destChainId) === $connectedSourceChain.id;

  $: if (correctChain) {
    canContinue = true;
  } else {
    canContinue = false;
  }

  const switchChains = async () => {
    $switchingNetwork = true;
    try {
      await switchChain(config, { chainId: Number(tx.destChainId) });
    } catch (err) {
      console.error(err);
    } finally {
      $switchingNetwork = false;
    }
  };
</script>

{#if correctChain}
  Lorem ipsum alles gut istum
{:else if tx.srcChainId && tx.destChainId && $connectedSourceChain.id}
  <div class="flex flex-col">
    <p>
      This transaction is bridging to <span class="font-bold text-primary">{txDestChainName}</span> You need to be connected
      to this chain
    </p>

    <ActionButton
      onPopup
      priority="primary"
      disabled={$switchingNetwork}
      loading={$switchingNetwork}
      on:click={() => {
        switchChains();
      }}>Switch to {txDestChainName}</ActionButton>
  </div>
{/if}
