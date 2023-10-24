<script lang="ts">
  import { Icon } from '$components/Icon';
  import NftInfoDialog from '$components/NFTList/NFTInfoDialog.svelte';
  import type { NFT } from '$libs/token';

  export let nft: NFT;
  export let selectNFT: (nft: NFT) => void;
  export let selectedNFT: NFT[] | null;

  const placeholderUrl = 'https://placehold.co/400x400.png';

  let imageUrl: string = nft.metadata?.image || placeholderUrl;

  let isChecked = false;

  let modalOpen = false;

  const handleDialogSelection = () => {
    selectNFT(nft);
    modalOpen = false;
  };

  const handleImageClick = () => {
    selectNFT(nft);
  };

  $: {
    isChecked = selectedNFT ? selectedNFT.some((selected) => selected.tokenId === nft.tokenId) : false;
  }
</script>

<div class="rounded-[10px] w-[120px] bg-white max-h-[161px] min-h-[161px] relative">
  <input type="radio" class="hidden" name="nft-radio" checked={isChecked} on:change={() => selectNFT(nft)} />
  {#if isChecked}
    <div class="selected-overlay">
      <Icon type="check-circle" class="f-center " fillClass="fill-primary-brand" width={40} height={40} />
    </div>
  {/if}
  <div
    role="button"
    tabindex="0"
    class="h-[125px] border-0 p-0"
    on:click={handleImageClick}
    on:keydown={handleImageClick}>
    <img alt={nft.name} src={imageUrl} />
  </div>
  <div class="f-between-center p-[8px]">
    <span class="font-bold text-black">{nft.tokenId} </span>
    <button class="mr-[10px]" on:click={() => (modalOpen = true)}
      ><Icon type="option-dots" fillClass="fill-grey-500" /></button>
  </div>
</div>

<NftInfoDialog {nft} bind:modalOpen on:selected={() => handleDialogSelection()} />

<style>
  /* Add styles for the overlay and checkmark icon */
  .selected-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-color: rgba(0, 0, 0, 0.5); /* Dark gray, semi-transparent */
    display: flex;
    align-items: center;
    justify-content: center;
  }
</style>
