<script lang="ts">
  import type { ethers } from "ethers";
  import Prover from "../../components/details/Prover.svelte";
  import Node from "../../components/details/Node.svelte";
  import Proposer from "../../components/details/Proposer.svelte";

  export let l1Provider: ethers.providers.JsonRpcProvider;
  export let l1TaikoAddress: string;
  export let l2Provider: ethers.providers.JsonRpcProvider;
  export let proposerAddress: string;
  export let proverAddress: string;
  export let eventIndexerApiUrl: string;

  let activeTab: string = "node";
</script>

<div class="text-center">
  <h1 class="text-2xl">simple-taiko-node dashboard</h1>
</div>
<div class="text-center mt-4 mb-4">
  <div class="tabs block">
    <a
      class="tab tab-lg tab-lifted"
      class:tab-active={activeTab === "node"}
      on:click={() => (activeTab = "node")}>Node</a
    >
    {#if proposerAddress}
      <a
        class="tab tab-lg tab-lifted"
        class:tab-active={activeTab === "proposer"}
        on:click={() => (activeTab = "proposer")}>Proposer</a
      >
    {/if}
    {#if proposerAddress}
      <a
        class="tab tab-lg tab-lifted"
        class:tab-active={activeTab === "prover"}
        on:click={() => (activeTab = "prover")}>Prover</a
      >
    {/if}
  </div>
</div>

{#if activeTab === "prover"}
  <Prover {l1Provider} {l2Provider} {proverAddress} {l1TaikoAddress} />
{:else if activeTab === "proposer"}
  <Proposer {l1Provider} {l2Provider} {proposerAddress} {l1TaikoAddress} />
{:else if activeTab === "node"}
  <Node {l1Provider} {l2Provider} {l1TaikoAddress} />
{/if}
