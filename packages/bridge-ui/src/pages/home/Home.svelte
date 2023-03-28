<script lang="ts">
  import { _ } from 'svelte-i18n';
  import { location } from 'svelte-spa-router';
  import { transactions } from '../../store/transactions';
  import BridgeForm from '../../components/form/BridgeForm.svelte';
  import TaikoBanner from '../../components/TaikoBanner.svelte';
  import Transactions from '../../components/Transactions';
  import { Tabs, TabList, Tab, TabPanel } from '../../components/Tabs';

  let bridgeWidth: number;
  let bridgeHeight: number;

  // List of tab's name <=> route association
  // TODO: add this into a general configuration.
  const tabsRoute = [
    { name: 'bridge', href: '/' },
    { name: 'transactions', href: '/transactions' },
    // Add more tabs if needed
  ];

  // TODO: we're assuming we have only two tabs here.
  //       Change strategy if needed.
  $: activeTab = $location === '/' ? tabsRoute[0].name : tabsRoute[1].name;

  // TODO: do we really need all these tricks to style containers
  //       Rethink this part: fluid, fixing on bigger screens
  $: isBridge = activeTab === tabsRoute[0].name;
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
    {@const tab1 = tabsRoute[0]}
    {@const tab2 = tabsRoute[1]}

    <TabList class="block mb-4">
      <Tab name={tab1.name} href={tab1.href}>Bridge</Tab>
      <Tab name={tab2.name} href={tab2.href}>
        Transactions ({$transactions.length})
      </Tab>
    </TabList>

    <TabPanel tab={tab1.name}>
      <TaikoBanner />
      <div class="px-4">
        <BridgeForm />
      </div>
    </TabPanel>

    <TabPanel tab={tab2.name}>
      <Transactions />
    </TabPanel>
  </Tabs>
</div>
