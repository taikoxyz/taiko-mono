<script lang="ts">
  import { createEventDispatcher } from 'svelte';

  import { Icon } from '$components/Icon';

  export let currentPage = 1;
  export let totalItems = 0;
  export let pageSize = 5;

  $: totalPages = Math.ceil(totalItems / pageSize);

  const dispatch = createEventDispatcher<{ pageChange: number }>();

  function goToPage(page: number) {
    currentPage = page;
    dispatch('pageChange', page);
  }

  function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Enter') {
       const nextPage = parseInt((event.target as HTMLInputElement).value, 10);

      // Check if input is within the valid range, otherwise do nothing
      if (nextPage > 0 && nextPage <= totalPages) {
        goToPage(nextPage);
      }
    }
  }

  const btnClass = 'btn btn-xs btn-ghost';

  $: isFirstPage = currentPage === 1;
  $: isLastPage = currentPage === totalPages;
</script>

{#if totalPages > 1}
  <!-- 
    We only want to show the buttons if we actually need them.
    If we can fit all the items in one page, there is no need.
  -->
  <div class="pagination btn-group pt-4">
    {#if !isFirstPage}
      <button class={btnClass} on:click={() => goToPage(currentPage - 1)}> <Icon type="chevron-left" /></button>
    {/if}
    Page
    <input
      type="number"
      class="form-control mx-1 text-center rounded-md py-1 px-8"
      bind:value={currentPage}
      min={1}
      max={totalPages}
      on:keydown={handleKeydown}
      on:blur={() => goToPage(currentPage)} />
    of {totalPages}
    <!-- The chevron-right displays as far as the current page is not the last page -->
    {#if !isLastPage}
      <button class={btnClass} on:click={() => goToPage(currentPage + 1)}><Icon type="chevron-right" /></button>
    {/if}
  </div>
{/if}

<style>
  .pagination {
    justify-content: flex-end;
    align-items: flex-end;
    gap: 10px;
    display: flex;
    align-items: center;
  }
</style>
