<script lang="ts">
  import { location } from 'svelte-spa-router';

  import { Tab, TabList, TabPanel, Tabs } from '../../components/Tabs';
  import History from '../../components/Events/History.svelte';
  import CurrentProvers from '../../components/CurrentProvers/CurrentProvers.svelte';
  import ProverInfo from '../../components/ProverInfo/ProverInfo.svelte';
  import StakeForm from '../..//components/StakeForm.svelte/StakeForm.svelte';
  import Rewards from '../../components/Rewards/Rewards.svelte';

  const tabsRoute = [
    { name: 'stake', href: '/' },
    { name: 'history', href: '/history' },
    { name: 'proverInfo', href: '/proverInfo' },
    { name: 'currentProvers', href: '/currentProvers' },
    { name: 'taikoToken', href: '/taikoToken' },
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
    {@const tab4 = tabsRoute[3]}
    {@const tab5 = tabsRoute[4]}

    <TabList class="block mb-4 w-full">
      <Tab type="main" name={tab1.name} href={tab1.href}>Stake</Tab>
      <Tab type="main" name={tab2.name} href={tab2.href}>History</Tab>
      <Tab type="main" name={tab3.name} href={tab3.href}>Prover Info</Tab>
      <Tab type="main" name={tab4.name} href={tab4.href}>Current Provers</Tab>
      <Tab type="main" name={tab5.name} href={tab5.href}>Taiko Token</Tab>
    </TabList>

    <TabPanel type={'main'} tab={tab1.name}>
      <div class="md:w-[440px] px-4"><StakeForm /></div>
    </TabPanel>

    <TabPanel type={'main'} tab={tab2.name}>
      <div class="md:min-w-[440px]">
        <History />
      </div>
    </TabPanel>

    <TabPanel type={'main'} tab={tab3.name}>
      <div class="md:w-[440px] px-4"><ProverInfo /></div>
    </TabPanel>

    <TabPanel type={'main'} tab={tab4.name}>
      <CurrentProvers />
    </TabPanel>

    <TabPanel type={'main'} tab={tab5.name}>
      <Rewards />
    </TabPanel>
  </Tabs>
</div>
