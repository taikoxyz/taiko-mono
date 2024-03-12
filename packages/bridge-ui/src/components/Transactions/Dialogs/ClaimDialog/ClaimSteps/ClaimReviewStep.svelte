<script lang="ts">
  import { onMount } from 'svelte';
  import { t } from 'svelte-i18n';
  import { formatEther, formatUnits } from 'viem';

  import ChainSymbolName from '$components/Transactions/ChainSymbolName.svelte';
  import type { BridgeTransaction, GetProofReceiptResponse } from '$libs/bridge';
  import { getInvocationDelaysForDestBridge } from '$libs/bridge/getInvocationDelaysForDestBridge';
  import { TokenType } from '$libs/token';
  export let tx: BridgeTransaction;

  export let proofReceipt: GetProofReceiptResponse;

  $: displayDelays = false;

  $: invocationDelay = 0n;

  onMount(async () => {
    const delays = await getInvocationDelaysForDestBridge(tx);
    // if we already have an initial proof, the delay applies
    if (delays[0] !== 0n && proofReceipt[0] !== 0n) {
      displayDelays = true;
      invocationDelay = delays[0]; // we only care about the preferred one
    }
  });
</script>

<div class="container mx-auto inline-block align-middle space-y-[25px] w-full mt-[30px]">
  <div class="flex justify-between mb-2 items-center">
    <div class="font-bold text-primary-content">{$t('bridge.nft.step.review.transfer_details')}</div>
  </div>
  <div>
    <div class="flex justify-between items-center">
      <div class="text-secondary-content">{$t('common.from')}</div>
      <ChainSymbolName chainId={tx.srcChainId} />
    </div>
    <div class="flex justify-between items-center">
      <div class="text-secondary-content">{$t('common.to')}</div>
      <ChainSymbolName chainId={tx.destChainId} />
    </div>
    {displayDelays}
    {invocationDelay}

    <!-- {proofReceipt[0]}
    {proofReceipt[1]} -->

    <!-- <div class="flex justify-between">
      <div class="text-secondary-content">{$t('common.token_standard')}</div>
      <div class="">{tx.tokenType}</div>
    </div> -->
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

<div class="h-sep" />
