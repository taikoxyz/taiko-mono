<script lang="ts">
  import type { BridgeTransaction } from "../domain/transactions";
  import ArrowLeft from "./icons/ArrowLeft.svelte";
  import Transaction from './Transaction.svelte';

  export let showTransactions = false;

  export let transactions: BridgeTransaction[] = [];

  const testTransactions = [
    {
      id: 1,
      name: "bla",
      chainID: 31336,
      status: 0,
      data: 'xyz',
    },
    {
      id: 2,
      name: "bla",
      chainID: 167001,
      status: 1,
      data: 'xyz',
    },
  ]
</script>

<div>
  <div class="px-2 py-4 flex items-center border-b border-b-dark-5" on:click={() => showTransactions = false}>
    <ArrowLeft />
    <span class="text-sm ml-2">Transactions</span>
  </div>
  {#each testTransactions as transaction}
    <Transaction {...transaction} />
  {/each}
</div>