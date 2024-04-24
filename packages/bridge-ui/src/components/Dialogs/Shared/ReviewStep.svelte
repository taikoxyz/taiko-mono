<script lang="ts">
  import { t } from 'svelte-i18n';
  import { formatEther, formatUnits } from 'viem';

  import ExplorerLink from '$components/ExplorerLink/ExplorerLink.svelte';
  import ChainSymbolName from '$components/Transactions/ChainSymbolName.svelte';
  import type { BridgeTransaction } from '$libs/bridge';
  import { type NFT, TokenType } from '$libs/token';
  import { shortenAddress } from '$libs/util/shortenAddress';

  export let tx: BridgeTransaction;
  export let nft: NFT | null = null;

  const placeholderUrl = '/placeholder.svg';

  $: imageUrl = nft?.metadata?.image || placeholderUrl;
  let imageLoaded = false;

  function handleImageLoad() {
    imageLoaded = true;
  }
</script>

<div class="space-y-[25px] mt-[20px]">
  <div class="flex justify-between mb-2 items-center">
    <div class="font-bold text-primary-content">{$t('transactions.claim.steps.review.title')}</div>
  </div>
  <div class="min-h-[150px] grid content-between">
    {#if nft}
      <div class="f-row justify-center">
        {#if !imageLoaded}
          <img alt="placeholder" src={placeholderUrl} class="rounded-[20px] bg-white max-w-[200px]" />
        {/if}
        <img
          alt="nft"
          src={imageUrl || ''}
          class="rounded-[20px] bg-white max-w-[200px] {!imageLoaded || imageUrl === '' ? 'hidden' : ''}"
          on:load={handleImageLoad} />
      </div>
    {/if}
    <div class="space-y-[5px]">
      <div class="flex justify-between items-center">
        <div class="text-secondary-content">{$t('common.from')}</div>
        <ChainSymbolName chainId={tx.srcChainId} />
      </div>
      <div class="flex justify-between items-center">
        <div class="text-secondary-content">{$t('common.to')}</div>
        <ChainSymbolName chainId={tx.destChainId} />
      </div>
      {#if tx.message}
        <div class="flex justify-between">
          <div class="text-secondary-content">{$t('common.sender')}</div>
          <ExplorerLink category="address" chainId={Number(tx.srcChainId)} urlParam={tx.message.from}
            >{shortenAddress(tx.message?.srcOwner, 5, 5)}</ExplorerLink>
        </div>

        <div class="flex justify-between">
          <div class="text-secondary-content">{$t('common.recipient')}</div>
          <div class="">
            <ExplorerLink category="address" chainId={Number(tx.destChainId)} urlParam={tx.message.to}
              >{shortenAddress(tx.message?.destOwner, 5, 5)}</ExplorerLink>
          </div>
        </div>
      {/if}
      {#if tx.amount !== 0n}
        <div class="flex justify-between">
          <div class="text-secondary-content">{$t('common.amount')}</div>
          {#if tx.tokenType === TokenType.ERC20}
            {formatUnits(tx.amount ? tx.amount : BigInt(0), tx.decimals)}
          {:else if tx.tokenType === TokenType.ETH}
            {formatEther(tx.amount ? tx.amount : BigInt(0))}
          {:else}
            {tx.amount}
          {/if}
          {tx.symbol}
        </div>
      {/if}
    </div>
  </div>
</div>
