<script lang="ts">
  import { transactions } from '../../store/transactions';
  import { paginationInfo } from '../../store/relayerApi';
  import Transaction from './Transaction.svelte';
  import TransactionDetail from './TransactionDetail.svelte';
  import MessageStatusTooltip from './MessageStatusTooltip.svelte';
  import InsufficientBalanceTooltip from './InsufficientBalanceTooltip.svelte';
  import type { BridgeTransaction } from '../../domain/transactions';
  import NoticeModal from '../modals/NoticeModal.svelte';
  import Paginator from '../Paginator.svelte';
  import Loading from '../Loading.svelte';

  let selectedTransaction: BridgeTransaction;
  let showMessageStatusTooltip: boolean;
  let showInsufficientBalance: boolean;
  let noticeModal: NoticeModal;

  let pageSize = 5;
  let currentPage = 1;
  let totalItems = 0;
  let loading = true;

  function getTransactionsToShow(
    page: number,
    pageSize: number,
    bridgeTx: BridgeTransaction[],
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

  $: if ($paginationInfo) {
    totalItems = $paginationInfo.total;
    loading = false;
  }
</script>

<div class="my-4 md:px-4">
  {#if transactionsToShow.length}
    <table class="table-auto my-4">
      <thead>
        <tr class="text-transaction-table">
          <th>From</th>
          <th>To</th>
          <th>Amount</th>
          <th>Status</th>
          <th>Details</th>
        </tr>
      </thead>
      <tbody class="text-sm md:text-base">
        {#each transactionsToShow as transaction (transaction.hash)}
          <Transaction
            on:claimNotice={({ detail }) => noticeModal.open(detail)}
            on:tooltipStatus={() => (showMessageStatusTooltip = true)}
            on:insufficientBalance={() => (showInsufficientBalance = true)}
            on:transactionDetails={() => {
              selectedTransaction = transaction;
            }}
            {transaction} />
        {/each}
      </tbody>
    </table>

    <div class="flex justify-end">
      <Paginator
        {pageSize}
        {totalItems}
        on:pageChange={({ detail }) => (currentPage = detail)} />
    </div>
  {:else if loading}
    <div class="flex flex-col items-center">
      <Loading width={150} height={150} />
      Loading transactions...
    </div>
  {:else}
    No transactions
  {/if}

  {#if selectedTransaction}
    <TransactionDetail
      transaction={selectedTransaction}
      onClose={() => (selectedTransaction = null)} />
  {/if}

  <MessageStatusTooltip bind:show={showMessageStatusTooltip} />

  <InsufficientBalanceTooltip bind:show={showInsufficientBalance} />

  <NoticeModal bind:this={noticeModal}>
    <!-- TODO: translations? -->
    <div class="text-center">
      When bridging, you selected the <strong>Recommended</strong> or
      <strong>Custom</strong> amount for the Processing Fee. You can wait for the
      relayer to auto-claim the bridged token or manually claim it now.
    </div>
  </NoticeModal>
</div>
