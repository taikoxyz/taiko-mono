<script lang="ts">
  import { location } from 'svelte-spa-router';
  import { transactions } from '../../store/transactions';
  import { paginationInfo } from '../../store/relayerApi';
  import { signer } from '../../store/signer';
  import BridgeForm from '../../components/form/BridgeForm.svelte';
  import TaikoBanner from '../../components/TaikoBanner.svelte';
  import Transactions from '../../components/Transactions';
  import { Tabs, TabList, Tab, TabPanel } from '../../components/Tabs';
  import Loading from '../../components/Loading.svelte';

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
</script>

<div class="container mx-auto text-center my-10">
  <Tabs
    class="rounded-3xl md:border-2 border-bridge-form border-solid p-2 md:p-6 md:inline-block min-h-[688px]"
    bind:activeTab>
    {@const tab1 = tabsRoute[0]}
    {@const tab2 = tabsRoute[1]}

    <TabList class="block mb-4">
      <Tab name={tab1.name} href={tab1.href}>Bridge</Tab>
      <Tab name={tab2.name} href={tab2.href}>
        <span>Transactions</span>
        {#if $paginationInfo || !$signer}
          ({$transactions.length})
        {:else}
          (<Loading />)
        {/if}
      </Tab>
    </TabList>

    <TabPanel tab={tab1.name}>
      <TaikoBanner />
      <div class="px-4 md:w-[440px]">
        <BridgeForm />
      </div>
    </TabPanel>

    <TabPanel tab={tab2.name}>
      <div class="md:min-w-[440px]">
        <Transactions />
      </div>
    </TabPanel>
  </Tabs>
</div>
