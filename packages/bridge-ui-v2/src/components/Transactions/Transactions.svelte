<script lang="ts">
  import { t } from 'svelte-i18n';
  import type { Address } from 'viem';

  import { activeBridge } from '$components/Bridge/state';
  import { BridgeTypes } from '$components/Bridge/types';
  import { Card } from '$components/Card';
  import { ChainSelector } from '$components/ChainSelector';
  import { DesktopOrLarger } from '$components/DesktopOrLarger';
  import { warningToast } from '$components/NotificationToast';
  import OnAccount from '$components/OnAccount/OnAccount.svelte';
  import { Paginator } from '$components/Paginator';
  import { Spinner } from '$components/Spinner';
  import { transactionConfig } from '$config';
  import { type BridgeTransaction, fetchTransactions, MessageStatus } from '$libs/bridge';
  import { bridgeTxService } from '$libs/storage';
  import { TokenType } from '$libs/token';
  import { account, network } from '$stores';
  import type { Account } from '$stores/account';

  import StatusFilterDropdown from './StatusFilterDropdown.svelte';
  import StatusInfoDialog from './StatusInfoDialog.svelte';
  import Transaction from './Transaction.svelte';

  let transactions: BridgeTransaction[] = [];

  let currentPage = 1;

  let isBlurred = false;
  const transitionTime = transactionConfig.blurTransitionTime;

  let totalItems = 0;
  let pageSize = transactionConfig.pageSizeDesktop;

  let loadingTxs = false;

  let isDesktopOrLarger: boolean;

  const handlePageChange = (detail: number) => {
    isBlurred = true;
    setTimeout(() => {
      currentPage = detail;
      isBlurred = false;
    }, transitionTime);
  };

  const getTransactionsToShow = (page: number, pageSize: number, bridgeTx: BridgeTransaction[]) => {
    const start = (page - 1) * pageSize;
    const end = start + pageSize;
    return bridgeTx.slice(start, end);
  };

  const onAccountChange = async (newAccount: Account, oldAccount?: Account) => {
    // We want to make sure that we are connected and only
    // fetch if the account has changed
    if (newAccount?.isConnected && newAccount.address && newAccount.address !== oldAccount?.address) {
      loadingTxs = true;

      try {
        await updateTransactions(newAccount.address);
      } catch (err) {
        console.error(err);
        // TODO: handle
      } finally {
        loadingTxs = false;
      }
    }
  };

  let selectedStatus: MessageStatus | null = null; // null indicates no filter is applied

  $: statusFilteredTransactions =
    selectedStatus !== null ? transactions.filter((tx) => tx.status === selectedStatus) : transactions;

  $: tokenAndStatusFilteredTransactions = statusFilteredTransactions.filter((tx) =>
    displayTokenTypesBasedOnType.includes(tx.tokenType),
  );

  $: transactionsToShow = getTransactionsToShow(currentPage, pageSize, tokenAndStatusFilteredTransactions);

  $: displayTokenTypesBasedOnType =
    $activeBridge === BridgeTypes.FUNGIBLE ? [TokenType.ERC20, TokenType.ETH] : [TokenType.ERC721, TokenType.ERC1155];

  $: filteredTransactions = transactions.filter((tx) => displayTokenTypesBasedOnType.includes(tx.tokenType));

  const updateTransactions = async (address: Address) => {
    const { mergedTransactions, outdatedLocalTransactions, error } = await fetchTransactions(address);
    transactions = mergedTransactions;

    if (outdatedLocalTransactions.length > 0) {
      await bridgeTxService.removeTransactions(address, outdatedLocalTransactions);
    }
    if (error) {
      warningToast({ title: $t('transactions.errors.relayer_offline') });
    }
  };

  $: pageSize = isDesktopOrLarger ? transactionConfig.pageSizeDesktop : transactionConfig.pageSizeMobile;

  $: totalItems = filteredTransactions.length;

  // Some shortcuts to make the code more readable
  $: isConnected = $account?.isConnected;
  $: hasTxs = filteredTransactions.length > 0;

  // Controls what we render on the page
  $: renderLoading = loadingTxs && isConnected;
  $: renderTransactions = !renderLoading && isConnected && hasTxs;
  $: renderNoTransactions = renderTransactions && transactionsToShow.length === 0;
</script>

<div class="flex flex-col justify-center w-full">
  <Card title={$t('transactions.title')} text={$t('transactions.description')}>
    <div class="space-y-[35px]">
      <div class="my-[30px] f-between-center max-h-[36px]">
        <ChainSelector label={$t('chain_selector.currently_on')} value={$network} switchWallet small />
        <StatusFilterDropdown bind:selectedStatus />
      </div>
      <div class="flex flex-col" style={`min-height: calc(${transactionsToShow.length} * 80px);`}>
        <div class="h-sep" />
        {#if isDesktopOrLarger}
          <div class="text-primary-content flex">
            {#if $activeBridge === BridgeTypes.FUNGIBLE}
              <div class="w-1/5 py-2 text-secondary-content">{$t('transactions.header.from')}</div>
              <div class="w-1/5 py-2 text-secondary-content">{$t('transactions.header.to')}</div>
              <div class="w-1/5 py-2 text-secondary-content">{$t('transactions.header.amount')}</div>
              <div class="w-1/5 py-2 text-secondary-content flex flex-row">
                {$t('transactions.header.status')}
                <StatusInfoDialog />
              </div>
              <div class="w-1/5 py-2 text-secondary-content">{$t('transactions.header.explorer')}</div>
            {:else if $activeBridge === BridgeTypes.NFT}
              <div class="w-2/6 py-2 text-secondary-content">Item</div>
              <div class="w-1/6 py-2 text-secondary-content">{$t('transactions.header.from')}</div>
              <div class="w-1/6 py-2 text-secondary-content">{$t('transactions.header.to')}</div>
              <div class="w-1/6 py-2 text-secondary-content">{$t('transactions.header.amount')}</div>
              <div class="w-1/6 py-2 text-secondary-content flex flex-row">
                {$t('transactions.header.status')}
                <StatusInfoDialog />
              </div>
              <div class="w-1/6 py-2 text-secondary-content">{$t('transactions.header.explorer')}</div>
            {/if}
          </div>
          <div class="h-sep !mb-0" />
        {/if}

        {#if renderLoading}
          <div class="flex items-center justify-center text-primary-content h-[80px]">
            <Spinner /> <span class="pl-3">{$t('common.loading')}...</span>
          </div>
        {/if}

        {#if renderTransactions}
          <div
            class="flex flex-col items-center"
            style={isBlurred ? `filter: blur(5px); transition: filter ${transitionTime / 1000}s ease-in-out` : ''}>
            {#each transactionsToShow as item (item.hash)}
              <Transaction {item} />
              {#if item.tokenType === TokenType.ERC721 || item.tokenType === TokenType.ERC1155}
                <div class="h-sep !mb-0" />
              {/if}
            {/each}
          </div>
        {/if}

        {#if renderNoTransactions}
          <div class="flex items-center justify-center text-primary-content h-[80px]">
            <span class="pl-3">{$t('transactions.no_transactions')}</span>
          </div>
        {/if}
      </div>
    </div>
  </Card>

  <div class="flex justify-end pt-2">
    <Paginator {pageSize} {totalItems} on:pageChange={({ detail }) => handlePageChange(detail)} />
  </div>
</div>

<OnAccount change={onAccountChange} />

<DesktopOrLarger bind:is={isDesktopOrLarger} />
