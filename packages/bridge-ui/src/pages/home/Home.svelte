<script lang="ts">
  import { _ } from 'svelte-i18n';
  import { link, location } from 'svelte-spa-router';
  import { transactions } from '../../store/transactions';
  import BridgeForm from '../../components/form/BridgeForm.svelte';
  import TaikoBanner from '../../components/TaikoBanner.svelte';
  import Transactions from '../../components/Transactions.svelte';

  let bridgeWidth: number;
  let bridgeHeight: number;

  $: activeTab = $location.replace('/', '').startsWith('transactions')
    ? 'transactions'
    : 'bridge';
  $: isBridge = activeTab === 'bridge';
  $: styleContainer = isBridge ? '' : `min-width: ${bridgeWidth}px;`;
  $: fitClassContainer = isBridge ? 'max-w-fit' : 'w-fit';
  $: styleInner =
    isBridge && $transactions.length > 0
      ? ''
      : `min-height: ${bridgeHeight}px;`;
</script>

<div
  class="container mx-auto text-center my-10 {fitClassContainer}"
  style={styleContainer}
  bind:clientWidth={bridgeWidth}
  bind:clientHeight={bridgeHeight}>
  <div
    class="rounded-3xl border-2 border-bridge-form border-solid p-2 md:p-6"
    style={styleInner}>
    <!-- TODO: extract this tab component into a general one? -->
    <div class="tabs block mb-4">
      <a
        class="tab tab-bordered {isBridge ? 'tab-active' : ''}"
        href="/"
        use:link>Bridge</a>
      <a
        class="tab tab-bordered {!isBridge ? 'tab-active' : ''}"
        href="/transactions"
        use:link>Transactions ({$transactions.length})</a>
    </div>

    {#if activeTab === 'bridge'}
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
