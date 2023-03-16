<script lang="ts">
  import { onDestroy } from 'svelte';
  import { chains } from '../domain/chain';
  import { transactions, transactioner } from '../store/transactions';
  import { signer } from '../store/signer';
  import {
    paginationParams,
    paginationResponse,
    relayerApi,
    relayerBlockInfoMap,
  } from '../store/relayerApi';
  import Transaction from './Transaction.svelte';
  import TransactionDetail from './TransactionDetail.svelte';
  import MessageStatusTooltip from './MessageStatusTooltip.svelte';
  import type { BridgeTransaction } from '../domain/transactions';
  import { MAX_PAGE_SIZE } from '../domain/relayerApi';
  import Pagination from './Pagination.svelte';

  let selectedTransaction: BridgeTransaction;
  let showMessageStatusTooltip: boolean;

  // TODO: maybe use svelte-query to cache results already fetched?
  const unsubscribe = paginationParams.subscribe(async (store) => {
    if (store && $signer) {
      const userAddress = await $signer.getAddress();

      const { txs: apiTxs, paginationResponse: pagination } =
        await $relayerApi.GetAllByAddress(userAddress, $paginationParams);

      paginationResponse.set(pagination);

      const blockInfoMap = $relayerBlockInfoMap;

      const txs = await $transactioner.GetAllByAddress(userAddress);

      const updatedStorageTxs: BridgeTransaction[] = txs.filter((tx) => {
        const blockInfo = blockInfoMap.get(tx.fromChainId);
        if (blockInfo?.latestProcessedBlock >= tx.receipt.blockNumber) {
          return false;
        }
        return true;
      });

      $transactioner.UpdateStorageByAddress(userAddress, updatedStorageTxs);

      transactions.set([...updatedStorageTxs, ...apiTxs]);
    }
  });

  onDestroy(() => {
    if (unsubscribe) {
      unsubscribe();
    }
  });
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
            toChain={chains[transaction.toChainId]}
            fromChain={chains[transaction.fromChainId]}
            {transaction} />
        {/each}
      </tbody>
    </table>
    <Pagination
      totalPages={$paginationResponse.totalPages}
      bind:page={$paginationParams.page} />
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
