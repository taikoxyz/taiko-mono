<script lang="ts">
  import { transactions } from '../../store/transactions';
  import { signer } from '../../store/signer';
  import { relayerApi, paginationInfo } from '../../store/relayerApi';
  import Transaction from './Transaction.svelte';
  import TransactionDetail from './TransactionDetail.svelte';
  import MessageStatusTooltip from './MessageStatusTooltip.svelte';
  import InsufficientBalanceTooltip from './InsufficientBalanceTooltip.svelte';
  import type { BridgeTransaction } from '../../domain/transactions';
  import NoticeModal from '../modals/NoticeModal.svelte';
  import Pagination from '../Pagination.svelte';
  import { MAX_PAGE_SIZE } from '../../domain/relayerApi';

  let selectedTransaction: BridgeTransaction;
  let showMessageStatusTooltip: boolean;
  let showInsufficientBalance: boolean;
  let noticeModal: NoticeModal;

  // let page = 1;
  // let size = 10;
  // $: totalPagesInTransactionList = $paginationInfo
  //   ? Math.ceil($paginationInfo?.total / size)
  //   : 0;

  // $: transactionsToShow = $transactions.slice(
  //   (page - 1) * size,
  //   (page - 1) * size + size,
  // );

  // async function loadMoreTransactionsFromAPI() {
  //   if (
  //     !$paginationInfo ||
  //     $paginationInfo.page + 1 >= $paginationInfo.max_page
  //   ) {
  //     return;
  //   }

  //   const userAddress = await $signer.getAddress();
  //   const { txs: apiTxs, paginationInfo: info } =
  //     await $relayerApi.getAllBridgeTransactionByAddress(userAddress, {
  //       page: $paginationInfo.page + 1,
  //       size: MAX_PAGE_SIZE,
  //     });
  //   paginationInfo.set(info);
  //   transactions.set([...$transactions, ...apiTxs]);
  // }

  // $: {
  //   if ($transactions.length > 0 && (page + 1) * size > $transactions.length) {
  //     loadMoreTransactionsFromAPI();
  //   }
  // }
</script>

<div class="my-4 md:px-4">
  <!-- {#if transactionsToShow.length} -->
  {#if $transactions.length}
    <table class="table-auto">
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
        <!-- {#each transactionsToShow as transaction (transaction.hash)} -->
        {#each $transactions as transaction (transaction.hash)}
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
    <!-- <Pagination totalPages={totalPagesInTransactionList} bind:page /> -->
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
