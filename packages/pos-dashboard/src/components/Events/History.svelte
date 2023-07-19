<script lang="ts">
  import { signer } from '../../store/signer';
  import Loading from '../Loading.svelte';
  import Paginator from '../Paginator.svelte';
  import { getSlashedTokensEvents } from '../../utils/getSlashedTokensEvents';
  import { EVENT_INDEXER_API_URL } from '../../constants/envVars';
  import type { APIResponseEvent } from '../../domain/api';
  import Event from './Event.svelte';
  import type { ethers } from 'ethers';
  import { getBlockProvenEvents } from '../../utils/getBlocksProven';
  import { getStakedEvents } from '../../utils/getStakedEvents';
  import { getWithdrawnEvents } from '../../utils/getWithdrawnEvents';
  import { getExitedEvents } from '../../utils/getExitedEvents';
  import { getAssignedBlocks } from '../../utils/getAssignedBlocks';
  import Tabs from '../Tabs/Tabs.svelte';
  import TabList from '../Tabs/TabList.svelte';
  import Tab from '../Tabs/Tab.svelte';
  import TabPanel from '../Tabs/TabPanel.svelte';
  import subKey from '../Tabs/Tabs.svelte';

  let pageSize = 8;
  let currentPage = 1;
  let totalItems = 0;
  let loading = true;
  let events: APIResponseEvent[] = [];
  let eventsToShow: APIResponseEvent[] = [];
  let activeTab: string = 'staked';

  function getEventsToShow(
    page: number,
    pageSize: number,
    allEvents: APIResponseEvent[],
  ) {
    if (!allEvents) return [];
    const start = (page - 1) * pageSize;
    const end = start + pageSize;
    loading = false;
    return allEvents.slice(start, end);
  }

  const tabs = [
    { name: 'Staked', href: '/history/staked' },
    { name: 'BlockProven', href: '/history/blockProven' },
    { name: 'Withdrawn', href: '/history/withdrawn' },
    { name: 'Exited', href: '/history/exited' },
    { name: 'Assigned', href: '/history/assigned' },
    { name: 'Slashed', href: '/history/slashed' },
  ];

  async function getEvents(signer: ethers.Signer, activeTab: string) {
    if (!signer) return [];

    switch (activeTab) {
      case tabs[0].name:
        return await getStakedEvents(EVENT_INDEXER_API_URL, signer);
      case tabs[1].name:
        return await getBlockProvenEvents(EVENT_INDEXER_API_URL, signer);
      case tabs[2].name:
        return await getWithdrawnEvents(EVENT_INDEXER_API_URL, signer);
      case tabs[3].name:
        return await getExitedEvents(EVENT_INDEXER_API_URL, signer);
      case tabs[4].name:
        return await getAssignedBlocks(EVENT_INDEXER_API_URL, signer);
      case tabs[5].name:
        return await getSlashedTokensEvents(EVENT_INDEXER_API_URL, signer);
      default:
        return [];
    }
  }

  $: eventsToShow = getEventsToShow(currentPage, pageSize, events);

  $: getEvents($signer, activeTab)
    .then((e) => (events = e))
    .catch(console.error);
</script>

<div class="my-4 md:px-4">
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
    bind:activeSubTab={activeTab}
    type="sub">
    <TabList class="block mb-4 w-full">
      {#each tabs as tab}
        <Tab type="sub" name={tab.name} href="">{tab.name}</Tab>
      {/each}
    </TabList>
  </Tabs>

  {#each tabs as tab}
    <TabPanel tab={tab.name}>
      {#if eventsToShow && eventsToShow.length}
        <table class="table-auto my-4">
          <thead>
            <tr>
              <th>Event</th>
              <th>Data</th>
            </tr>
          </thead>
          <tbody class="text-sm md:text-base">
            {#each eventsToShow as event}
              <Event {event} />
            {/each}
          </tbody>
        </table>

        <div class="flex justify-end">
          <Paginator
            {pageSize}
            {totalItems}
            on:pageChange={({ detail }) => (currentPage = detail)} />
        </div>
      {:else if loading && $signer}
        <div class="flex flex-col items-center">
          <Loading width={150} height={150} />
          Loading event history...
        </div>
      {:else}
        No history. When you have a {tab.name} event, those events will show here.
      {/if}
    </TabPanel>
  {/each}
</div>
