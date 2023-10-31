<script lang="ts">
  import { selectedNFTs } from '$components/Bridge/state';
  import { Icon } from '$components/Icon';
  import NftInfoDialog from '$components/NFTs/NFTInfoDialog.svelte';
  import type { NFT } from '$libs/token';

  export let nft: NFT;
  export let selectNFT: (nft: NFT) => void;
  export let viewOnly: boolean;

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
    isChecked = $selectedNFTs ? $selectedNFTs.some((selected) => selected.tokenId === nft.tokenId) : false;
  }
</script>

<div class="rounded-[10px] w-[120px] bg-white max-h-[160px] min-h-[160px] relative">
  {#if !viewOnly}
    <label for="nft-radio" class="cursor-pointer">
      <input type="radio" class="hidden" name="nft-radio" checked={isChecked} on:change={() => selectNFT(nft)} />

      {#if isChecked}
        <div
          class="selected-overlay rounded-[10px]"
          role="button"
          tabindex="0"
          on:click={handleImageClick}
          on:keydown={handleImageClick}>
          <Icon type="check-circle" class="f-center " fillClass="fill-primary-brand" width={40} height={40} />
        </div>
      {/if}
      <div role="button" tabindex="0" class="h-[124px]" on:click={handleImageClick} on:keydown={handleImageClick}>
        <img alt={nft.name} src={imageUrl} class="rounded-t-[10px] h-[125px]" />
      </div>
    </label>
  {:else}
    <img alt={nft.name} src={imageUrl} class="rounded-t-[10px] h-[125px]" />
  {/if}

  <button
    name="nftInfoDialog"
    class="px-[10px] py-[8px] h-[36px] f-between-center w-full"
    on:click={() => (modalOpen = true)}
    ><span class="font-bold text-black">{nft.tokenId} </span>
    <Icon type="option-dots" fillClass="fill-grey-500" /></button>
</div>

<NftInfoDialog {nft} bind:modalOpen on:selected={() => handleDialogSelection()} {viewOnly} />

<style>
  .selected-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-color: rgba(11, 16, 27, 0.7); /* Gray-900 0.7 opacity */
    display: flex;
    align-items: center;
    justify-content: center;
    border: 3px solid var(--primary-brand);
  }
</style>
