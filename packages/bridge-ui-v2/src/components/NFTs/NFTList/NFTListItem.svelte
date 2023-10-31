<script lang="ts">
  import { t } from 'svelte-i18n';
  import type { Address } from 'viem';

  import { selectedNFTs } from '$components/Bridge/state';
  import { Icon } from '$components/Icon';
  import NftInfoDialog from '$components/NFTs/NFTInfoDialog.svelte';
  import { type NFT, TokenType } from '$libs/token';
  import { noop } from '$libs/util/noop';

  export let nft: NFT;
  export let collectionAddress: Address;
  export let multiSelectEnabled = false;
  export let checkedAddresses: Map<string, boolean> = new Map();
  export let selectNFT: (nft: NFT) => void;
  export let toggleAddressCheckBox: (collectionAddress: string) => void = noop;
  export let selectable = false;

  let selected: boolean = false;

  let modalOpen = false;

  const placeholderUrl = 'https://placehold.co/400x400.png';

  let imageUrl: string = nft.metadata?.image || placeholderUrl;
  let imageLoaded = false;

  const handleDialogSelection = () => {
    selectNFT(nft);
    selected = true;
    modalOpen = false;
  };

  function handleImageLoad() {
    imageLoaded = true;
  }

  $: {
    selected = $selectedNFTs ? $selectedNFTs.some((selected) => selected.tokenId === nft.tokenId) : false;
  }
</script>

<div class="form-control flex">

  <label class="cursor-pointer label my-[8px] space-x-[16px]">
    {#if multiSelectEnabled && selectable}
      <input
        type="checkbox"
        class="checkbox checkbox-secondary"
        checked={checkedAddresses.get(collectionAddress) || false}
        on:change={() => toggleAddressCheckBox(collectionAddress)} />
    {:else if selectable}
      <input
        type="radio"
        name="nft-radio"
        checked={selected}
        class="flex-none radio radio-secondary"
        on:change={() => selectNFT(nft)} />
    {/if}
    <div class="avatar h-[56px] w-[56px]">
      <div class="rounded-[10px] bg-primary-background">
        {#if !imageLoaded}
          <img alt="placeholder" src={placeholderUrl} class="rounded animate-pulse" />
        {/if}
        <img alt="placeholder nft" src={imageUrl || ''} class=" rounded" on:load={handleImageLoad} />
      </div>
    </div>
    <div class="f-col grow">
      {#if nft.metadata?.name}
        <span class="text-xs text-neutral-content font-bold">{nft.metadata?.name}</span>
      {/if}
      <span class=" text-xs text-neutral-content">{$t('common.id')}: {nft.tokenId}</span>
      {#if nft.type === TokenType.ERC1155}
        <span class=" text-xs text-neutral-content">{$t('common.balance')}: {nft.balance}</span>
      {/if}
    </div>
    <button on:click={() => (modalOpen = true)}><Icon type="option-dots" /></button>
  </label>
</div>

<NftInfoDialog {nft} bind:modalOpen on:selected={() => handleDialogSelection()} />

<style>
  /* Todo: temporary test, remove or move */
  .animate-pulse {
    animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
  }

  @keyframes pulse {
    0%,
    100% {
      opacity: 1;
    }
    50% {
      opacity: 0.5;
    }
  }
</style>
