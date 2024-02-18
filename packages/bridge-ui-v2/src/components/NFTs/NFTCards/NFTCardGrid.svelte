<script lang="ts">
  import { get } from 'svelte/store';

  import { selectedNFTs, selectedToken } from '$components/Bridge/state';
  import { NFTCard } from '$components/NFTs/NFTCards';
  import type { NFT } from '$libs/token';
  import { groupNFTByCollection } from '$libs/util/groupNFTByCollection';
  import { connectedSourceChain } from '$stores/network';

  export let nfts: NFT[] = [];
  export let viewOnly = false;

  const selectNFT = (nft: NFT) => {
    const currentChainId = get(connectedSourceChain)?.id;

    if (!currentChainId || !nft) return;
    const address = nft.addresses[currentChainId];
    const foundNFT = nfts.find((n) => n.addresses[currentChainId] === address && nft.tokenId === n.tokenId);

    if ($selectedNFTs && foundNFT && $selectedNFTs.includes(foundNFT)) {
      $selectedNFTs = $selectedNFTs.filter((selected) => selected.tokenId !== nft.tokenId); // Deselect
      $selectedToken = null;
    } else {
      $selectedNFTs = foundNFT ? [foundNFT] : null; // Select
      if ($selectedNFTs) $selectedToken = $selectedNFTs[0];
    }
  };

  $: collections = groupNFTByCollection(nfts);
</script>

{#each Object.entries(collections) as [address, nftsGroup] (address)}
  {@const chainId = $connectedSourceChain?.id}
  <div class="">
    {#if nftsGroup.length > 0 && chainId}
      <div class="collection-header">
        <span class="font-bold text-primary-content">
          {nftsGroup[0].name}
        </span>
        <span class="badge badge-primary badge-outline badge-xs px-[10px] h-[24px] ml-[10px]"
          ><span class="text-xs">{nftsGroup[0].type}</span></span>
      </div>
      <div class="token-ids mt-[16px] grid gap-4 md:grid-cols-3 grid-cols-2">
        {#each nftsGroup as nft}
          <NFTCard {nft} {selectNFT} {viewOnly} />
        {/each}
      </div>
      {#if Object.keys(collections).length > 1 || nfts.length > 3}
        <div class="h-sep my-[30px]" />
      {/if}
    {/if}
  </div>
{/each}
