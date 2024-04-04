<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';

  import { Icon } from '$components/Icon';

  export let currentPage = 1;
  export let totalItems = 0;
  export let pageSize = 5;

  $: totalPages = Math.max(1, Math.ceil(totalItems / pageSize));

  const dispatch = createEventDispatcher<{ pageChange: number }>();

  function goToPage(page: number) {
    currentPage = Math.min(totalPages, Math.max(1, page));
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

  // Computed flags for first and last page
  $: isFirstPage = currentPage === 1;
  $: isLastPage = currentPage === totalPages;
</script>

{#if totalPages > 1}
  <!-- Show pagination buttons if needed -->
  <div class="pagination btn-group pt-4">
    {#if !isFirstPage}
      <!-- Button to go to previous page -->
      <button class={btnClass} on:click={() => goToPage(currentPage - 1)}> <Icon type="chevron-left" /></button>
    {/if}
    {$t('paginator.page')}
    <input
      type="number"
      class="form-control mx-1 text-center rounded-md py-1 px-8"
      bind:value={currentPage}
      min={1}
      max={totalPages}
      on:keydown={handleKeydown}
      on:blur={() => goToPage(currentPage)} />
    {$t('paginator.of')}
    {totalPages}
    <!-- Button to go to next page -->
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
