<!--
  Binds a Paginator the way Transactions does, so a test can watch what the parent's page
  is while the page box is being edited.
-->
<script lang="ts">
  import { Paginator } from '$components/Paginator';

  export let currentPage = 1;
  export let totalItems = 0;
  export let pageSize = 5;
</script>

<span data-testid="page">{String(currentPage)}</span>
<Paginator bind:currentPage {totalItems} {pageSize} />
