<script lang="ts">
  import { onMount } from 'svelte';
  import { type Unsubscriber, writable } from 'svelte/store';
  import { t } from 'svelte-i18n';

  import { Button } from '$components/Button';
  import { Card } from '$components/Card';
  import OnAccount from '$components/OnAccount/OnAccount.svelte';
  import { Paginator } from '$components/Paginator';
  import { Spinner } from '$components/Spinner';
  import { activitiesConfig } from '$config';
  import { PUBLIC_RELAYER_URL } from '$env/static/public';
  import type { BridgeTransaction } from '$libs/bridge';
  import { web3modal } from '$libs/connect';
  import { RelayerAPIService } from '$libs/relayer/RelayerAPIService';
  import { bridgeTxService } from '$libs/storage/services';
  import { getLogger } from '$libs/util/logger';
  import { mergeUniqueTransactions } from '$libs/util/mergeTransactions';
  import { type Account, account } from '$stores/account';
  import { paginationInfo as paginationStore } from '$stores/relayerApi';

  import MobileDetailsDialog from './MobileDetailsDialog.svelte';
  import Transaction from './Transaction.svelte';

  const log = getLogger('Transactions.svelte');

  export const transactions = writable<BridgeTransaction[]>([]);

  let currentPage = 1;

  let isBlurred = false;
  const transitionTime = activitiesConfig.blurTransitionTime;

  const handlePageChange = (detail: number) => {
    isBlurred = true;
    setTimeout(() => {
      currentPage = detail;
      isBlurred = false;
    }, transitionTime);
  };

  const relayerApi = new RelayerAPIService(PUBLIC_RELAYER_URL);

  let totalItems = 0;
  let pageSize = activitiesConfig.pageSizeDesktop;
  $: pageSize = isMobile ? activitiesConfig.pageSizeMobile : activitiesConfig.pageSizeDesktop;

  let loadingTxs = true;

  let unsubscribe: Unsubscriber;
  let detailsOpen = false;
  let isMobile = false;

  let selectedItem: BridgeTransaction | null = null;

  onMount(async () => {
    if (!$account?.isConnected) {
      loadingTxs = false;
      return;
    }
    await fetchTransactions();
  });

  const getTransactionsToShow = (page: number, pageSize: number, bridgeTx: BridgeTransaction[]) => {
    const start = (page - 1) * pageSize;
    const end = start + pageSize;
    return bridgeTx.slice(start, end);
  };

  // Todo: move logic out of component
  const fetchTransactions = async () => {
    loadingTxs = true;
    if (!$account.address || totalItems > 0) {
      loadingTxs = false;
      return;
    }

    // Transactions from local storage
    const localTxs: BridgeTransaction[] = await bridgeTxService.getAllTxByAddress($account.address);

    // Transactions from relayer
    const { txs, paginationInfo } = await relayerApi.getAllBridgeTransactionByAddress($account.address, {
      page: 0,
      size: 100,
    });

    loadingTxs = false;

    $transactions = mergeUniqueTransactions(localTxs, txs);

    log(`merging ${localTxs.length} local and ${txs.length} relayer transactions. New size: ${$transactions.length}`);

    paginationStore.set(paginationInfo);
  };

  const onWalletConnect = () => web3modal.openModal();

  const onAccountChange = async (newAccount: Account, oldAccount?: Account) => {
    if (newAccount?.isConnected) {
      await fetchTransactions();
    }
  };

  const closeDetails = () => {
    detailsOpen = false;
    selectedItem = null;
  };

  const openDetails = (tx: BridgeTransaction) => {
    detailsOpen = true;
    selectedItem = tx;
  };

  $: transactionsToShow = getTransactionsToShow(currentPage, pageSize, $transactions);

  $: if ($paginationStore) {
    totalItems = $transactions.length;
  }
</script>

<div class="flex flex-col justify-center w-full">
  <Card title={$t('activities.title')} text={$t('activities.description')}>
    <div class="flex flex-col" style={`min-height: calc(${transactionsToShow.length} * 80px);`}>
      {#if !isMobile}
        <div class="h-sep" />
        <div class=" text-white flex">
          <div class="w-1/5 px-4 py-2">{$t('activities.header.from')}</div>
          <div class="w-1/5 px-4 py-2">{$t('activities.header.to')}</div>
          <div class="w-1/5 px-4 py-2">{$t('activities.header.amount')}</div>
          <div class="w-1/5 px-4 py-2">{$t('activities.header.status')}</div>
          <div class="w-1/5 px-4 py-2">{$t('activities.header.explorer')}</div>
        </div>
        <div class="h-sep" />
      {/if}
      {#if transactionsToShow.length && !loadingTxs && $account?.isConnected}
        <div
          class="flex flex-col items-center"
          style={isBlurred ? `filter: blur(5px); transition: filter ${transitionTime / 1000}s ease-in-out` : ''}>
          {#each transactionsToShow as item (item.hash)}
            <Transaction {item} on:click={isMobile ? () => openDetails(item) : undefined} />
            <div class="h-sep" />
          {/each}
        </div>
      {/if}
      {#if loadingTxs && $account?.isConnected}
        <div class="flex items-center justify-center text-white h-[80px]">
          <Spinner /> <span class="pl-3">{$t('common.loading')}...</span>
        </div>
      {:else if !transactionsToShow.length && $account?.isConnected}
        <div class="flex items-center justify-center text-white h-[80px]">
          <span class="pl-3">{$t('activities.no_transactions')}</span>
        </div>
      {:else if !$account?.isConnected}
        <div class="flex items-center justify-center text-white h-[80px]">
          <Button type="primary" on:click={onWalletConnect} class="px-[28px] py-[14px] ">
            <span class="body-bold">{$t('wallet.connect')}</span>
          </Button>
        </div>
      {/if}
    </div>
  </Card>

  <div class="flex justify-end pt-2">
    <Paginator {pageSize} {totalItems} on:pageChange={({ detail }) => handlePageChange(detail)} />
  </div>
</div>

<MobileDetailsDialog {closeDetails} {detailsOpen} {selectedItem} />

<OnAccount change={onAccountChange} />
