<script lang="ts">
  import type { APIResponseEvent } from 'src/domain/api';

  export let event: APIResponseEvent;
</script>

<tr>
  <td>
    <span class="ml-2 hidden md:inline-block">{event.event}</span>
  </td>
  <td>
    {event.data.Raw.transactionHash}
  </td>
</tr>

<style>
  td {
    padding: 1rem;
  }
</style>
