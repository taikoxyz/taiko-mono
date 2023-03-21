<script lang="ts">
  import { _ } from 'svelte-i18n';
  import { location } from 'svelte-spa-router';
  import { transactions } from '../../store/transactions';
  import BridgeForm from '../../components/form/BridgeForm.svelte';
  import TaikoBanner from '../../components/TaikoBanner.svelte';
  import Transactions from '../../components/Transactions.svelte';
  import { Tabs, TabList, Tab, TabPanel } from '../../components/Tabs';

  let bridgeWidth: number;
  let bridgeHeight: number;

  // TODO: think about a more general approach here.
  //       We're assuming we have two tabs. The base location
  //       corresponds with `bridge` tab => `/`, otherwise we're
  //       opening the second tab `transactions` => `/transactions`.
  //       What if we add a new tab?. Also, routes are coupled to
  //       tab's name. We might want to have this configuration
  //       somewhere.
  $: activeTab = $location === '/' ? 'bridge' : 'transactions';

  // TODO: do we really need all these tricks to style containers
  //       Rethink this part: fluid, fixing on bigger screens
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
  <Tabs
    class="rounded-3xl border-2 border-bridge-form border-solid p-2 md:p-6"
    style={styleInner}
    bind:activeTab>
    <TabList class="block mb-4">
      <Tab name="bridge" href="/">Bridge</Tab>
      <Tab name="transactions" href="/transactions">
        Transactions ({$transactions.length})
      </Tab>
    </TabList>

    <TabPanel tab="bridge">
      <TaikoBanner />
      <div class="px-4">
        <BridgeForm />
      </div>
    </TabPanel>

    <TabPanel tab="transactions">
      <Transactions />
    </TabPanel>
  </Tabs>
</div>
