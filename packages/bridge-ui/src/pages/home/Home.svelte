<script lang="ts">
  import { _ } from "svelte-i18n";
  import { transactions } from "../../store/transactions";
  import BridgeForm from "../../components/form/BridgeForm.svelte";
  import TaikoBanner from "../../components/TaikoBanner.svelte";
  import Transactions from "../../components/Transactions.svelte";

  let activeTab: string = "bridge";
  let bridgeWidth: number;
  let bridgeHeight: number;

  $: isBridge = activeTab === 'bridge'
  $: styleContainer = isBridge ? '' : `min-width: ${bridgeWidth}px;`
  $: fitClassContainer = isBridge ? 'max-w-fit' : 'w-fit'
  $: styleInner = isBridge && $transactions.length > 0 ? '' : `min-height: ${bridgeHeight}px;`

</script>

<div 
  class="container mx-auto text-center my-10 {fitClassContainer}"
  style={styleContainer}
  bind:clientWidth={bridgeWidth}
  bind:clientHeight={bridgeHeight}
>
  <div 
    class="rounded-3xl border-2 border-bridge-form border-solid p-2 md:p-6"
    style={styleInner}>
    
    <!-- TODO: extract this tab component into a general one? -->
    <div role="tablist" class="tabs block mb-4">
      <button
        role="tab"
        aria-selected="true"
        class="tab tab-bordered {isBridge ? 'tab-active' : ''}"
        on:click={() => activeTab = "bridge"}
      >
        Bridge
      </button>
      <button
        role="tab"
        class="tab tab-bordered {!isBridge ? 'tab-active' : ''}"
        on:click={() => activeTab = "transactions"}
      >
        Transactions ({$transactions.length})
      </button>
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
