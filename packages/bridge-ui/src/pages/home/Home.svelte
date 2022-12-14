<script lang="ts">
  import { transactions } from "../../store/transactions";
  import { _ } from "svelte-i18n";

  import BridgeForm from "../../components/form/BridgeForm.svelte";
  import TaikoBanner from "../../components/TaikoBanner.svelte";
  import Transactions from "../../components/Transactions.svelte";
  let activeTab: string = "bridge";
</script>

<div class="hero bg-base-100">
  <div class="hero-content text-center">
    <div class="">
      <div class="tabs">
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
</div>

<style>
  .tabs {
    display: block;
  }
</style>
