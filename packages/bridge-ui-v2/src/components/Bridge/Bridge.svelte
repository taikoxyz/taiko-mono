<script lang="ts">
  import { activeTab } from '$stores/bridgetabs';

  import Erc20Bridge from './ERC20Bridge.svelte';
  import NftBridge from './NFTBridge.svelte';
</script>

{#if $activeTab === 'erc20_tab'}
  <Erc20Bridge />
{:else if $activeTab === 'nft_tab'}
  <NftBridge />
{/if}
