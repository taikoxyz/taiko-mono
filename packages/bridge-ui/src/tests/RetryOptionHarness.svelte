<script lang="ts">
  import RetryOptionStep from '$components/Dialogs/RetryDialog/RetrySteps/RetryOptionStep.svelte';
  import type { BridgeTransaction } from '$libs/bridge/types';

  export let bridgeTx: BridgeTransaction;
  let reviewing = false;
  let canContinue = false;
</script>

{#if reviewing}
  <button on:click={() => (reviewing = false)}>Back</button>
{:else}
  <RetryOptionStep {bridgeTx} bind:canContinue />
  <button disabled={!canContinue} on:click={() => (reviewing = true)}>Continue</button>
{/if}
