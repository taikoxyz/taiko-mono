<script lang="ts">
  import { location } from 'svelte-spa-router';

  import { Tab, TabList, TabPanel, Tabs } from '../../components/Tabs';
  import Transactions from '../../components/Transactions';

  // List of tab's name <=> route association
  // TODO: add this into a general configuration.
  const tabsRoute = [
    { name: 'stake', href: '/' },
    { name: 'history', href: '/history' },
    { name: 'whatever', href: '/whatever' },
    // Add more tabs if needed
  ];

  $: activeTab =
    $location === '/' ? tabsRoute[0].name : $location.replace('/', '');
</script>

<div class="container mx-auto text-center my-10">
  <Tabs
    class="
      tabs 
      md:bg-tabs 
      md:border-2 
      md:dark:border-1 
      md:border-gray-200 
      md:dark:border-gray-800 
      md:shadow-md 
      md:rounded-3xl 
      md:p-6 
      md:inline-block 
      md:min-h-[650px]
      p-2"
    bind:activeTab>
    {@const tab1 = tabsRoute[0]}
    {@const tab2 = tabsRoute[1]}
    {@const tab3 = tabsRoute[2]}

    <TabList class="block mb-4 w-full">
      <Tab name={tab1.name} href={tab1.href}>Stake</Tab>
      <Tab name={tab2.name} href={tab2.href}>History</Tab>
      <Tab name={tab3.name} href={tab3.href}>Whatever</Tab>
    </TabList>

    <TabPanel tab={tab1.name}>
      <div class="md:w-[440px] px-4">StakeForm</div>
    </TabPanel>

    <TabPanel tab={tab2.name}>
      <div class="md:min-w-[440px]">
        <Transactions />
      </div>
    </TabPanel>

    <TabPanel tab={tab3.name}>
      <div class="md:w-[440px] px-4">Whatever</div>
    </TabPanel>
  </Tabs>
</div>
