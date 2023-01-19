<script lang="ts">
  import { transactions } from "../../store/transactions";
  import { _ } from "svelte-i18n";

  import BridgeForm from "../../components/form/BridgeForm.svelte";
  import TaikoBanner from "../../components/TaikoBanner.svelte";
  import Transactions from "../../components/Transactions.svelte";
  let activeTab: string = "bridge";
  let bridgeWidth;
  let bridgeHeight;
</script>

<div class="container mx-auto {activeTab === 'bridge' ? 'max-w-fit' : 'w-fit'} text-center my-10" style="{activeTab === 'bridge' ? '' : 'min-width: '+bridgeWidth+'px;'}" bind:clientWidth={bridgeWidth} bind:clientHeight={bridgeHeight}>
  <div class="rounded-3xl border-2 border-bridge-form border-solid p-2 md:p-6" style="{activeTab === 'bridge' && $transactions.length > 0 ? '' : 'min-height: '+bridgeHeight+'px;'}">
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
