<script lang="ts">
  import { get } from 'svelte/store';

  import { selectedNFTs } from '$components/Bridge/state';
  import { NFTCard } from '$components/NFTs/NFTCards';
  import type { NFT } from '$libs/token';
  import { groupNFTByCollection } from '$libs/util/groupNFTByCollection';
  import { network } from '$stores/network';

  export let nfts: NFT[] = [];
  export let viewOnly = false;

  const selectNFT = (nft: NFT) => {
    const currentChainId = get(network)?.id;

    if (!currentChainId || !nft) return;
    const address = nft.addresses[currentChainId];
    const foundNFT = nfts.find((n) => n.addresses[currentChainId] === address && nft.tokenId === n.tokenId);

    if ($selectedNFTs && foundNFT && $selectedNFTs.includes(foundNFT)) {
      $selectedNFTs = $selectedNFTs.filter((selected) => selected.tokenId !== nft.tokenId); // Deselect
    } else {
      $selectedNFTs = foundNFT ? [foundNFT] : null; // Select
    }
  };
</script>

<div class="">
  {#each Object.entries(groupNFTByCollection(nfts)) as [address, nftsGroup] (address)}
    {@const chainId = $network?.id}
    <div class="">
      {#if nftsGroup.length > 0 && chainId}
        <div class="collection-header">
          <span class="font-bold text-primary-content">
            {nftsGroup[0].name}
          </span>
          <span class="badge badge-primary badge-outline badge-xs px-[10px] h-[24px] ml-[10px]"
            ><span class="text-xs">{nftsGroup[0].type}</span></span>
        </div>
        <div class="token-ids my-[16px] grid grid-cols-3 gap-4">
          {#each nftsGroup as nft}
            {@const collectionAddress = nft.addresses[chainId]}
            {#if collectionAddress === undefined}
              <div>TODO: Address for {nft.name} is undefined</div>
            {:else}
              <NFTCard {nft} {selectNFT} {viewOnly} />
            {/if}
          {/each}
        </div>
      {/if}
    </div>
    <div class="h-sep my-[30px]" />
  {/each}
</div>
