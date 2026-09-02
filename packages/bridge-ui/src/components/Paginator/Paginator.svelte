<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';

  import { Icon } from '$components/Icon';

  export let currentPage = 1;
  export let totalItems = 0;
  export let pageSize = 5;

  /**
   * What the page box shows while the user types. The box used to be bound straight to
   * `currentPage`, which the parent binds in turn, so every keystroke reached the list
   * before goToPage could clamp it: an emptied box became page `null`, a typed 0 or a
   * negative a page that does not exist, and the rows vanished behind "No transactions"
   * until blur. The page only moves through goToPage, on Enter or blur.
   */
  let pageDraft: number | null = currentPage;
  $: pageDraft = currentPage;

  $: totalPages = Math.max(1, Math.ceil(totalItems / pageSize));

  const dispatch = createEventDispatcher<{ pageChange: number }>();

  function goToPage(page: number | null) {
    // Dispatch the clamped value: the raw input can be out of range (typed page numbers)
    currentPage = Math.min(totalPages, Math.max(1, Number.isInteger(page) ? (page as number) : 1));
    // The box shows the page that was actually reached, also when the clamp left the page as it was
    pageDraft = currentPage;
    dispatch('pageChange', currentPage);
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

  const btnClass = 'btn btn-xs btn-ghost disabled:bg-transparent disabled:cursor-not-allowed';

  // Computed flags for first and last page
  $: isFirstPage = currentPage === 1;
  $: isLastPage = currentPage === totalPages;
</script>

{#if totalPages > 1}
  <!-- Show pagination buttons if needed -->
  <div class="pagination btn-group pt-4">
    <!-- Button to go to previous page -->
    <button disabled={isFirstPage} class={btnClass} on:click={() => goToPage(currentPage - 1)}>
      <Icon type="chevron-left" /></button>
    {$t('paginator.page')}
    <input
      type="number"
      class="form-control mx-1 text-center rounded-full bg-neutral-background border-none py-1 px-8"
      bind:value={pageDraft}
      min={1}
      max={totalPages}
      on:keydown={handleKeydown}
      on:blur={() => goToPage(pageDraft)} />
    {$t('paginator.of')}
    {totalPages}
    <!-- Button to go to next page -->
    <button disabled={isLastPage} class={btnClass} on:click={() => goToPage(currentPage + 1)}
      ><Icon type="chevron-right" /></button>
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
