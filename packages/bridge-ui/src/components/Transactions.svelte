<script lang="ts">
  import { chains } from "../domain/chain";
  import { transactions } from "../store/transactions";
  import ArrowLeft from "./icons/ArrowLeft.svelte";
  import Transaction from "./Transaction.svelte";

  export let showTransactions = false;
</script>

<div>
  <div
    class="px-2 py-4 flex items-center border-b border-b-dark-5"
    on:click={() => (showTransactions = false)}
  >
    <ArrowLeft />
    <span class="text-sm ml-2">Transactions</span>
  </div>
  {#each $transactions as transaction}
    <Transaction
      toChain={chains[transaction.message.destChainId]}
      fromChain={chains[transaction.message.srcChainId]}
      {transaction}
    />
  {/each}
</div>
