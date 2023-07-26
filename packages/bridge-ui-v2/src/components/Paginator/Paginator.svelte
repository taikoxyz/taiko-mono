<script lang="ts">
  import { createEventDispatcher } from 'svelte';

  import { Icon } from '$components/Icon';

  export let currentPage = 1;
  export let totalItems = 0;
  export let pageSize = 5;
  export let buttonsToShow = 5;
  $: totalPages = Math.ceil(totalItems / pageSize);
  $: buttons = Math.min(buttonsToShow, totalPages);

  $: startPage = Math.max(1, currentPage - Math.floor(buttons / 2));
  $: endPage = Math.min(totalPages, startPage + buttons - 1);
  $: pages = Array.from({ length: endPage - startPage + 1 }, (_, i) => startPage + i);

  const dispatch = createEventDispatcher<{ pageChange: number }>();

  function goToPage(page: number) {
    currentPage = page;
    dispatch('pageChange', page);
  }

  function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Enter') {
      goToPage(currentPage);
    }
  }
</script>

{#if totalPages > 1}
  <!-- 
    We only want to show the buttons if we actually need them.
    If we can fit all the items in one page, there is no need.
  -->
  <div class="pagination btn-group">
    <button class="btn btn-xs" on:click={() => goToPage(currentPage - 1)} disabled={currentPage === 1}>
      <Icon type="chevron-left" /></button>
    Page
    <input
      type="number"
      class="form-control mx-1 text-center rounded-md py-1 px-8"
      bind:value={currentPage}
      min={1}
      max={totalPages}
      on:keydown={handleKeydown}
      on:blur={() => goToPage(currentPage)} />
    of {totalPages} Pages
    <button class="btn btn-xs" on:click={() => goToPage(currentPage + 1)} disabled={currentPage === totalPages}
      ><Icon type="chevron-right" /></button>
  </div>
{/if}

<style>
  .pagination {
    display: inline-flex;
    justify-content: flex-end;
    align-items: flex-end;
    gap: 20px;
  }
</style>
