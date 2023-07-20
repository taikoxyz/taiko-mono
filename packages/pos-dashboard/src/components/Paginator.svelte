<script lang="ts">
  import { createEventDispatcher } from 'svelte';

  export let currentPage = 1;
  export let totalItems = 0;
  export let pageSize = 5;
  export let buttonsToShow = 5;

  const totalPages = Math.ceil(totalItems / pageSize);
  const buttons = Math.min(buttonsToShow, totalPages);

  $: startPage = Math.max(1, currentPage - Math.floor(buttons / 2));
  $: endPage = Math.min(totalPages, startPage + buttons - 1);
  $: pages = Array.from(
    { length: endPage - startPage + 1 },
    (_, i) => startPage + i,
  );

  const dispatch = createEventDispatcher<{ pageChange: number }>();

  function goToPage(page: number) {
    currentPage = page;
    dispatch('pageChange', page);
  }
</script>

<!-- 
    We only want to show the buttons if we actually need them.
    If we can fit all the items in one page, there is no need.
  -->
<div class="pagination btn-group">
  <button
    class="btn btn-xs"
    on:click={() => goToPage(1)}
    disabled={currentPage === 1}>First</button>
  <button
    class="btn btn-xs"
    on:click={() => goToPage(currentPage - 1)}
    disabled={currentPage === 1}>Previous</button>
  {#each pages as page (page)}
    <button
      class="btn btn-xs"
      class:btn-active={currentPage === page}
      on:click={() => goToPage(page)}>{page}</button>
  {/each}
  <button
    class="btn btn-xs"
    on:click={() => goToPage(currentPage + 1)}
    disabled={currentPage === totalPages}>Next</button>
  <button
    class="btn btn-xs"
    on:click={() => goToPage(totalPages)}
    disabled={currentPage === totalPages}>Last</button>
</div>

<style>
  .pagination .btn-active {
    color: white;
    background-color: hsla(var(--af) / var(--tw-bg-opacity, 1));
  }
</style>
