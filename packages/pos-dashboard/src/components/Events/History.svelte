<script lang="ts">
  import { signer } from '../../store/signer';
  import Loading from '../Loading.svelte';
  import Paginator from '../Paginator.svelte';
  import { getSlashedTokensEvents } from '../../utils/getSlashedTokensEvents';
  import { EVENT_INDEXER_API_URL } from '../../constants/envVars';
  import type { APIResponseEvent } from '../../domain/api';
  import { ethers } from 'ethers';
  import { getBlockProvenEvents } from '../../utils/getBlocksProven';
  import { getStakedEvents } from '../../utils/getStakedEvents';
  import { getWithdrawnEvents } from '../../utils/getWithdrawnEvents';
  import { getExitedEvents } from '../../utils/getExitedEvents';
  import { getAssignedBlocks } from '../../utils/getAssignedBlocks';

  let pageSize = 10;
  let currentPage = 1;
  let totalItems = 0;
  let events: APIResponseEvent[] = [];
  let eventsToShow: APIResponseEvent[] = [];
  let activeTab: string = 'Staked';
  let loading: boolean = false;

  function getEventsToShow(
    page: number,
    pageSize: number,
    allEvents: APIResponseEvent[],
  ) {
    loading = true;
    try {
      if (!allEvents) return [];
      const start = (page - 1) * pageSize;
      const end = start + pageSize;
      const ret = allEvents.slice(start, end);
      return ret;
    } finally {
      loading = false;
    }
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
    loading = true;
    let items = [];
    if (!signer) return [];

    switch (activeTab) {
      case tabs[0].name:
        items = await getStakedEvents(EVENT_INDEXER_API_URL, signer);
        break;
      case tabs[1].name:
        items = await getBlockProvenEvents(EVENT_INDEXER_API_URL, signer);
        break;
      case tabs[2].name:
        items = await getWithdrawnEvents(EVENT_INDEXER_API_URL, signer);
        break;
      case tabs[3].name:
        items = await getExitedEvents(EVENT_INDEXER_API_URL, signer);
        break;
      case tabs[4].name:
        items = await getAssignedBlocks(EVENT_INDEXER_API_URL, signer);
        break;
      case tabs[5].name:
        items = await getSlashedTokensEvents(EVENT_INDEXER_API_URL, signer);
        break;
      default:
        items = [];
        break;
    }

    totalItems = items.length;
    return items;
  }

  $: eventsToShow = getEventsToShow(currentPage, pageSize, events);

  $: getEvents($signer, activeTab)
    .then((e) => (events = e))
    .catch(console.error);
</script>

<div class="my-4 md:px-4">
  <div
    class="tabs md:bg-tabs
  md:border-2
  md:dark:border-1
  md:border-gray-200
  md:dark:border-gray-800
  md:shadow-md
  md:rounded-3xl
  md:p-6
  md:inline-block
  md:min-h-[650px]
  p-2">
    {#each tabs as tab}
      <a
        class="tab tab-bordered {tab.name === activeTab ? 'tab-active' : ''}"
        on:click={() => {
          eventsToShow = [];
          activeTab = tab.name;
        }}>{tab.name}</a>
    {/each}

    {#each tabs as tab}
      <div class={activeTab === tab.name ? '' : 'hidden'}>
        {#if eventsToShow && eventsToShow.length && !loading}
          <table class="table-auto my-4">
            <thead>
              <tr>
                <th>Event</th>
                {#if tab.name === tabs[0].name}
                  <th>Amount</th>
                {:else if tab.name === tabs[1].name}
                  <th>Block ID</th>
                {:else if tab.name === tabs[2].name}
                  <th>Amount</th>
                {:else if tab.name === tabs[3].name}{:else if tab.name === tabs[4].name}
                  <th>Block ID</th>
                {:else if tab.name === tabs[5].name}
                  <th>Amount</th>
                {/if}
              </tr>
            </thead>
            <tbody class="text-sm md:text-base">
              {#each eventsToShow as event}
                <tr>
                  <td>
                    <span
                      on:click={() =>
                        window.open(
                          `https://explorer.test.taiko.xyz/tx/${event.data.Raw.transactionHash}`,
                          '_blank',
                        )}
                      class="cursor-pointer ml-2 hidden md:inline-block"
                      >{event.event}</span>
                  </td>
                  {#if activeTab === tabs[0].name}
                    <td>{ethers.utils.formatUnits(event.amount, 8)} TTKOe</td>
                  {:else if activeTab === tabs[1].name}
                    <td>{event.blockID.Int64}</td>
                  {:else if activeTab === tabs[2].name}{:else if activeTab === tabs[3].name}{:else if activeTab === tabs[4].name}
                    <td>{event.blockID.Int64}</td>
                  {:else if activeTab === tabs[5].name}
                    <td>{ethers.utils.formatUnits(event.amount, 8)} TTKOe</td
                    >{/if}
                </tr>
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
      </div>
    {/each}
  </div>
</div>
