<script lang="ts">
  import { get } from 'svelte/store';
  import { t } from 'svelte-i18n';
  import type { Address } from 'viem';

  import type { NFT } from '$libs/token';
  import { truncateString } from '$libs/util/truncateString';
  import { network } from '$stores/network';

  export let nft: NFT;

  const placeholderUrl = 'https://placehold.co/400x400.png';

  let imageUrl: string = nft.metadata?.image || placeholderUrl;

  let chainId: number | undefined;
  let address: Address;

  $: if (nft) {
    chainId = get(network)?.id;
    if (chainId) {
      address = nft.addresses[chainId];
    }
  }
</script>

<div class="rounded max-w-[200px] border-2 border-primary-border m-5 max-h-[300px]">
  <img alt={nft.name} src={imageUrl} />
  <div class="f-col p-5 text-xs">
    {#if nft.name}<span
        ><span class="font-bold">{$t('common.collection')}:</span>
        <span class="text-secondary-content">{nft.name}</span></span
      >{/if}
    {#if nft.symbol}
      <span><span class="text-secondary-content">{nft.symbol}</span></span>
    {/if}

    {#if nft.metadata?.name}
      <span
        ><span class="font-bold">{$t('common.name')}:</span>
        <span class="text-secondary-content">{nft.metadata?.name}</span></span>
    {/if}
    <!-- {#if nft.metadata?.description}
      {nft.metadata?.description}
    {/if} -->

    <span
      ><span class="font-bold">{$t('common.id')}: </span><span class="text-secondary-content"
        >{nft.tokenId}
      </span></span>
    <span
      ><span class="font-bold">{$t('common.address')}: </span><span class="text-secondary-content"
        >{truncateString(address, 13)}
      </span>
    </span>
  </div>
</div>
