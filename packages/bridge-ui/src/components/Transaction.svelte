<script lang="ts">
  import { chains } from "../domain/chain";
  import Loader from "./icons/Loader.svelte";
  import TransactionsIcon from "./icons/Transactions.svelte";

  export let id: number;
  export let name: string;
  export let data: string;
  export let status: number;
  export let chainID: number;

  // TODO: uncomment this when fromChainID is available
  // export let fromChainID: number;
  let fromChainID: number = chainID == 167001 ? 31336 : 167001;

  let fromChain = chains[fromChainID];
  let toChain = chains[chainID];

  let amount = 0.001;

  let isPending = status === 0;
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
    {amount} ETH

    {#if isPending}
    <div class="animate-spin">
      <Loader />
    </div>
    {:else}
      <TransactionsIcon />
    {/if}
  </div>
</div>