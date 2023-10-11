<script lang="ts">
  import { get } from 'svelte/store';
  import { t } from 'svelte-i18n';
  import type { Address } from 'viem';

  import { type NFT, TokenType } from '$libs/token';
  import { fetchNFTImageUrl } from '$libs/token/fetchNFTImageUrl';
  import { noop } from '$libs/util/noop';
  import { network } from '$stores/network';

  export let nft: NFT;
  export let collectionAddress: Address;
  export let multiSelectEnabled = false;
  export let checkedAddresses: Map<string, boolean> = new Map();
  export let selectNFT: (nft: NFT) => void;
  export let toggleAddressCheckBox: (collectionAddress: string) => void = noop;
  export let selectable = false;

  let imageUrl: string | null = null;
  let imageLoaded = false;
  let chainId: number | undefined;
  const placeholderUrl = '/chains/taiko.svg';

  $: if (nft) {
    chainId = get(network)?.id;
    if (chainId) {
      fetchImage(nft);
    }
  }

  async function fetchImage(nft: NFT) {
    imageUrl = await fetchNFTImageUrl(nft);
  }

  function handleImageLoad() {
    imageLoaded = true;
  }
</script>

<div class="form-control flex">
  <label class="cursor-pointer label">
    <div class="mr-2">
      <div class="avatar">
        <div class="w-10 mask mask-hexagon">
          {#if !imageLoaded}
            <img alt="placeholder" src={placeholderUrl} class="w-[40px] h-[40px] rounded animate-pulse" />
          {/if}
          <img alt="placeholder nft" src={imageUrl || ''} class="w-[40px] h-[40px] rounded" on:load={handleImageLoad} />
          <img alt="placeholder nft" src={imageUrl} class="w-[40px] h-[40px] rounded" />
        </div>
      </div>
    </div>
    <div class="f-col grow">
      {#if nft.metadata?.name}
        <span class=" text-xs text-neutral-content">{nft.metadata?.name}</span>
      {/if}
      <span class=" text-xs text-neutral-content">{$t('common.id')}: {nft.tokenId}</span>
      {#if nft.type === TokenType.ERC1155}
        <span class=" text-xs text-neutral-content">{$t('common.balance')}: {nft.balance}</span>
      {/if}
    </div>
    {#if multiSelectEnabled && selectable}
      <input
        type="checkbox"
        class="checkbox checkbox-secondary"
        checked={checkedAddresses.get(collectionAddress) || false}
        on:change={() => toggleAddressCheckBox(collectionAddress)} />
    {:else if selectable}
      <input type="radio" name="nft-radio" class="flex-none radio radio-secondary" on:change={() => selectNFT(nft)} />
    {/if}
  </label>
</div>

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
