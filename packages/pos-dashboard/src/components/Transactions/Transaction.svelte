<script lang="ts">
  import { type TransactionReceipt } from '../../domain/transaction';

  export let transaction: TransactionReceipt;
</script>

<tr>
  <td>
    <span class="ml-2 hidden md:inline-block"
      >{transaction.transactionHash}</span>
  </td>
  <td />
</tr>

<style>
  td {
    padding: 1rem;
  }
</style>
