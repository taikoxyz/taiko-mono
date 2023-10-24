<script lang="ts">
  import type { NFT } from '$libs/token';

  import { NFTCard } from '.';

  export let nfts: NFT[] = [];
</script>

<div>
  {#each nfts as nft}
    <NFTCard {nft} />
  {/each}
</div>
