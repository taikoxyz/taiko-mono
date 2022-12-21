<script lang="ts">
  import { transactions } from "../../store/transactions";
  import { _ } from "svelte-i18n";

  import BridgeForm from "../../components/form/BridgeForm.svelte";
  import TaikoBanner from "../../components/TaikoBanner.svelte";
  import Transactions from "../../components/Transactions.svelte";
  let activeTab: string = "bridge";
</script>

<div class="container mx-auto max-w-fit text-center my-10">
  <div class="rounded-3xl border-2 border-zinc-800 border-solid p-6">
    <div class="tabs mb-4">
      <span
        class="tab tab-bordered {activeTab === 'bridge' ? 'tab-active' : ''}"
        on:click={() => (activeTab = "bridge")}>Bridge</span
      >
      <span
        class="tab tab-bordered {activeTab !== 'bridge' ? 'tab-active' : ''}"
        on:click={() => (activeTab = "transactions")}
        >Transactions ({$transactions.length})
      </span>
    </div>
    {#if activeTab === "bridge"}
      <TaikoBanner />
      <div class="px-4">
        <BridgeForm />
      </div>
    {:else}
      <Transactions />
    {/if}
  </div>
</div>

<style>
  .tabs {
    display: block;
  }
</style>
