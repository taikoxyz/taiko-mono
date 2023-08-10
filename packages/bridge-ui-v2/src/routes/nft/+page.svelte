<script>
  import NftBridge from '$components/Bridge/NFTBridge.svelte';
  import { Page } from '$components/Page';
  import { PUBLIC_NFT_BRIDGE_ENABLED } from '$env/static/public';
</script>

<Page>
  {#if PUBLIC_NFT_BRIDGE_ENABLED === 'true'}
    <NftBridge />
  {/if}
</Page>
