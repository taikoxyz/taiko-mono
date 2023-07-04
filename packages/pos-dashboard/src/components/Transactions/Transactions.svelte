<script lang="ts">
  import type { TransactionReceipt } from '../../domain/transaction';
  import { signer } from '../../store/signer';
  import { transactions } from '../../store/transaction';
  import Loading from '../Loading.svelte';
  import Paginator from '../Paginator.svelte';
  import Transaction from './Transaction.svelte';

  let pageSize = 8;
  let currentPage = 1;
  let totalItems = 0;
  let loadingTxs = true;

  function getTransactionsToShow(
    page: number,
    pageSize: number,
    bridgeTx: TransactionReceipt[],
  ) {
    const start = (page - 1) * pageSize;
    const end = start + pageSize;
    return bridgeTx.slice(start, end);
  }

  $: transactionsToShow = getTransactionsToShow(
    currentPage,
    pageSize,
    $transactions,
  );
</script>

<div class="my-4 md:px-4">
  {#if transactionsToShow.length}
    <table class="table-auto my-4">
      <thead>
        <tr>
          <th>From</th>
          <th>To</th>
          <th>Amount</th>
          <th>Status</th>
          <th>Details</th>
        </tr>
      </thead>
      <tbody class="text-sm md:text-base">
        {#each transactionsToShow as transaction (transaction.transactionHash)}
          <Transaction {transaction} />
        {/each}
      </tbody>
    </table>

    <div class="flex justify-end">
      <Paginator
        {pageSize}
        {totalItems}
        on:pageChange={({ detail }) => (currentPage = detail)} />
    </div>
  {:else if loadingTxs && $signer}
    <div class="flex flex-col items-center">
      <Loading width={150} height={150} />
      Loading transactions…
    </div>
  {:else}
    No transactions.
  {/if}
</div>
