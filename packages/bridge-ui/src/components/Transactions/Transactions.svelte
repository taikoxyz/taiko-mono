<script lang="ts">
  import type { BridgeTransaction } from '../../domain/transaction';
  import { paginationInfo } from '../../store/relayerApi';
  import { signer } from '../../store/signer';
  import { transactions } from '../../store/transaction';
  import Loading from '../Loading.svelte';
  import NoticeModal from '../NoticeModal.svelte';
  import Paginator from '../Paginator.svelte';
  import InsufficientBalanceTooltip from './InsufficientBalanceTooltip.svelte';
  import MessageStatusTooltip from './MessageStatusTooltip.svelte';
  import Transaction from './Transaction.svelte';
  import TransactionDetail from './TransactionDetail.svelte';

  let selectedTransaction: BridgeTransaction;
  let showMessageStatusTooltip: boolean;
  let showInsufficientBalance: boolean;
  let noticeModal: NoticeModal;

  let pageSize = 8;
  let currentPage = 1;
  let totalItems = 0;
  let loadingTxs = true;

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
    totalItems = $transactions.length;
    loadingTxs = false;
  }
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
  {:else if loadingTxs && $signer}
    <div class="flex flex-col items-center">
      <Loading width={150} height={150} />
      Loading transactions…
    </div>
  {:else}
    No transactions.
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
