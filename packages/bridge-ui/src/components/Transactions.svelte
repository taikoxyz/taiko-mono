<script lang="ts">
  import { chains } from "../domain/chain";
  import type { BridgeTransaction } from "../domain/transactions";
  import ArrowLeft from "./icons/ArrowLeft.svelte";
  import Transaction from "./Transaction.svelte";

  export let showTransactions = false;

  export let transactions: BridgeTransaction[] = [];
</script>

<div>
  <div
    class="px-2 py-4 flex items-center border-b border-b-dark-5"
    on:click={() => (showTransactions = false)}
  >
    <ArrowLeft />
    <span class="text-sm ml-2">Transactions</span>
  </div>
  {#each transactions as transaction}
    <Transaction
      toChain={chains[transaction.rawData.Message.DestChainId]}
      fromChain={chains[transaction.rawData.Message.SrcChainId]}
      {transaction}
    />
  {/each}
</div>
