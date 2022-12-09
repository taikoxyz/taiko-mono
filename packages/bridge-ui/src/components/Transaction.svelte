<script lang="ts">
  import type { BridgeTransaction } from "../domain/transactions";
  import type { Chain } from "../domain/chain";
  import Loader from "./icons/Loader.svelte";
  import TransactionsIcon from "./icons/Transactions.svelte";
  import { MessageStatus } from "../domain/message";

  export let transaction: BridgeTransaction;

  export let fromChain: Chain;
  export let toChain: Chain;
</script>

<div class="p-2">
  <div class="flex items-center justify-between text-xs">
    <div class="flex items-center">
      <svelte:component this={fromChain.icon} height={18} width={18} />
      <span class="ml-2">From {fromChain.name}</span>
    </div>
    <div class="flex items-center">
      <svelte:component this={toChain.icon} height={18} width={18} />
      <span class="ml-2">To {toChain.name}</span>
    </div>
  </div>
  <div class="px-1 py-2 flex items-center justify-between">
    {transaction.rawData.Message.DepositValue}
    {transaction.rawData.Message.Data ? "TKO" : "ETH"}

    {#if transaction.status === MessageStatus.New}
      <div class="animate-spin">
        <Loader />
      </div>
    {:else}
      <TransactionsIcon />
    {/if}
  </div>
</div>
