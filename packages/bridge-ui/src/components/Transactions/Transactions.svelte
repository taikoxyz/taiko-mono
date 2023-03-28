<script lang="ts">
  import { transactions } from '../../store/transactions';
  import Transaction from './Transaction.svelte';
  import TransactionDetail from './TransactionDetail.svelte';
  import MessageStatusTooltip from './MessageStatusTooltip.svelte';
  import InsufficientBalanceTooltip from './InsufficientBalanceTooltip.svelte';
  import type { BridgeTransaction } from '../../domain/transactions';
  import OptInOutTooltip from '../OptInOutTooltip.svelte';

  let selectedTransaction: BridgeTransaction;
  let showMessageStatusTooltip: boolean;
  let showInsufficientBalance: boolean;
  let showRelayerAutoclaimTooltip: boolean;

  // TODO: temporary hack until we move the claim and release functions
  //       outside of the Transaction component.
  let confirmNotice: (informed: boolean) => Promise<void>;
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
            on:tooltipClick={() => (showMessageStatusTooltip = true)}
            on:insufficientBalance={() => (showInsufficientBalance = true)}
            on:relayerAutoClaim={({ detail }) => {
              confirmNotice = detail;
              showRelayerAutoclaimTooltip = true;
            }}
            on:transactionDetailsClick={() => {
              selectedTransaction = transaction;
            }}
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

  <OptInOutTooltip
    bind:show={showRelayerAutoclaimTooltip}
    onConfirm={confirmNotice}
    name="RelayerAutoclaim">
    <!-- TODO: translations? -->
    <div class="text-center">
      When bridging, you selected the <strong>Recommended</strong> amount for the
      Processing Fee. You can wait the relayer to auto-claim then bridged token or
      you can manually claim it now.
    </div>
  </OptInOutTooltip>
</div>
