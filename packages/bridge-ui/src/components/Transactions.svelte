<script lang="ts">
  import { chainsRecord } from '../chain/chains';
  import type { BridgeTransaction } from '../domain/transactions';
  import { transactions } from '../store/transactions';
  import MessageStatusTooltip from './MessageStatusTooltip.svelte';
  import Transaction from './Transaction.svelte';
  import TransactionDetail from './TransactionDetail.svelte';

  let selectedTransaction: BridgeTransaction;
  let showMessageStatusTooltip: boolean;
</script>

<div class="my-4 md:px-4">
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
        {#each $transactions as transaction}
          <Transaction
            onTooltipClick={() => {
              showMessageStatusTooltip = true;
            }}
            onShowTransactionDetailsClick={() => {
              selectedTransaction = transaction;
            }}
            toChain={chainsRecord[transaction.toChainId]}
            fromChain={chainsRecord[transaction.fromChainId]}
            {transaction} />
        {/each}
      </tbody>
    </table>
  {:else}
    No transactions
  {/if}

  {#if selectedTransaction}
    <TransactionDetail
      transaction={selectedTransaction}
      onClose={() => (selectedTransaction = null)} />
  {/if}

  <MessageStatusTooltip show={showMessageStatusTooltip} />
</div>
