<script lang="ts">
  import { transactions } from '../store/transactions';
  import Transaction from './Transaction.svelte';
  import TransactionDetail from './TransactionDetail.svelte';
  import MessageStatusTooltip from './MessageStatusTooltip.svelte';
  import InsufficientBalanceTooltip from './InsufficientBalanceTooltip.svelte';
  import type { BridgeTransaction } from '../domain/transactions';
  import { chains } from '../chain/chains';

  let selectedTransaction: BridgeTransaction;
  let showMessageStatusTooltip: boolean;
  let showInsufficientBalance: boolean;
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
            onTooltipClick={(showInsufficientBalanceMessage = false) => {
              if (showInsufficientBalanceMessage) {
                showInsufficientBalance = true;
              } else {
                showMessageStatusTooltip = true;
              }
            }}
            onShowTransactionDetailsClick={() => {
              selectedTransaction = transaction;
            }}
            toChain={chains[transaction.toChainId]}
            fromChain={chains[transaction.fromChainId]}
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

  <MessageStatusTooltip bind:show={showMessageStatusTooltip} />
  <InsufficientBalanceTooltip bind:show={showInsufficientBalance} />
</div>
