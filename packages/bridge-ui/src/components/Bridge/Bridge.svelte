<script lang="ts">
  import FungibleBridge from './FungibleBridge.svelte';
  import NftBridge from './NFTBridge.svelte';
  import { activeBridge } from './state';
  import { BridgeTypes } from './types';
</script>

{#if $activeBridge === BridgeTypes.FUNGIBLE}
  <FungibleBridge />
{:else}
  <NftBridge />
{/if}
