<script lang="ts">
  import { t } from 'svelte-i18n';
  import { formatEther, formatUnits } from 'viem';

  import ExplorerLink from '$components/ExplorerLink/ExplorerLink.svelte';
  import ChainSymbolName from '$components/Transactions/ChainSymbolName.svelte';
  import type { BridgeTransaction } from '$libs/bridge';
  import { TokenType } from '$libs/token';
  import { shortenAddress } from '$libs/util/shortenAddress';
  export let tx: BridgeTransaction;
</script>

<div class="container mx-auto inline-block align-middle space-y-[25px] w-full mt-[20px]">
  <div class="flex justify-between mb-2 items-center">
    <div class="font-bold text-primary-content">{$t('transactions.claim.steps.review.title')}</div>
  </div>
  <div class="space-y-[10px]">
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
          >{shortenAddress(tx.message?.from, 5, 5)}</ExplorerLink>
      </div>
      <div class="flex justify-between">
        <div class="text-secondary-content">{$t('common.recipient')}</div>
        <div class="">
          <ExplorerLink category="address" chainId={Number(tx.destChainId)} urlParam={tx.message.to}
            >{shortenAddress(tx.message?.to, 5, 5)}</ExplorerLink>
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
        {/if}
        {tx.symbol}
      </div>
    {/if}
  </div>
</div>
