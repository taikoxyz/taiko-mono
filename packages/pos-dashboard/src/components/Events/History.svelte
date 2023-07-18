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

  let pageSize = 8;
  let currentPage = 1;
  let totalItems = 0;
  let loading = true;
  let events: APIResponseEvent[] = [];
  let eventsToShow: APIResponseEvent[] = [];

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

  async function getEvents(signer: ethers.Signer) {
    if (!signer) return [];
    const slashed = await getSlashedTokensEvents(EVENT_INDEXER_API_URL, signer);
    const blockProven = await getBlockProvenEvents(
      EVENT_INDEXER_API_URL,
      signer,
    );

    return slashed.concat(blockProven);
  }

  $: eventsToShow = getEventsToShow(currentPage, pageSize, events);

  $: getEvents($signer)
    .then((e) => (events = e))
    .catch(console.error);
</script>

<div class="my-4 md:px-4">
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
    No history. When you have proven a block or been slashed, those events will
    show here.
  {/if}
</div>
