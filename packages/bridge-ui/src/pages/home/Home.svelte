<script lang="ts">
  import { location } from 'svelte-spa-router';

  import BridgeForm from '../../components/BridgeForm';
  import SelectChain from '../../components/BridgeForm/SelectChain.svelte';
  import Faucet from '../../components/Faucet/Faucet.svelte';
  import Loading from '../../components/Loading.svelte';
  import { Tab, TabList, TabPanel, Tabs } from '../../components/Tabs';
  import Transactions from '../../components/Transactions';
  import { ENABLE_FAUCET } from '../../constants/envVars';
  import { paginationInfo } from '../../store/relayerApi';
  import { signer } from '../../store/signer';
  import { transactions } from '../../store/transaction';

  // List of tab's name <=> route association
  // TODO: add this into a general configuration.
  const tabsRoute = [
    { name: 'bridge', href: '/' },
    { name: 'transactions', href: '/transactions' },
    { name: 'faucet', href: '/faucet' }, // faucet wont be used if disabled in env
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

    <TabList class="block mb-4 w-full">
      <Tab name={tab1.name} href={tab1.href}>Bridge</Tab>
      <Tab name={tab2.name} href={tab2.href}>
        <span>Transactions</span>
        {#if $paginationInfo || !$signer}
          ({$transactions.length})
        {:else}
          (<Loading />)
        {/if}
      </Tab>
      {#if ENABLE_FAUCET}
        <Tab name={tabsRoute[2].name} href={tabsRoute[2].href}>Faucet</Tab>
      {/if}
    </TabList>

    <TabPanel tab={tab1.name}>
      <div class="rounded-lg py-4 flex flex-col items-center justify-center">
        <SelectChain />
      </div>
      <div class="md:w-[440px] px-4">
        <BridgeForm />
      </div>
    </TabPanel>

    <TabPanel tab={tab2.name}>
      <div class="md:min-w-[440px]">
        <Transactions />
      </div>
    </TabPanel>

    {#if ENABLE_FAUCET}
      <TabPanel tab={tabsRoute[2].name}>
        <div class="md:w-[440px] px-4">
          <Faucet />
        </div>
      </TabPanel>
    {/if}
  </Tabs>
</div>
