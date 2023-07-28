<script lang="ts">
  import { onMount } from 'svelte';
  import { writable } from 'svelte/store';
  import { fade } from 'svelte/transition';
  import { t } from 'svelte-i18n';

  import { Button } from '$components/Button';
  import { Card } from '$components/Card';
  import OnAccount from '$components/OnAccount/OnAccount.svelte';
  import { Paginator } from '$components/Paginator';
  import { Spinner } from '$components/Spinner';
  import { PUBLIC_RELAYER_URL } from '$env/static/public';
  import type { BridgeTransaction } from '$libs/bridge';
  import { web3modal } from '$libs/connect';
  import { RelayerAPIService } from '$libs/relayer/RelayerAPIService';
  import { bridgeTxService } from '$libs/storage/services';
  import { getLogger } from '$libs/util/logger';
  import { mergeUniqueTransactions } from '$libs/util/mergeTransactions';
  import { type Account, account } from '$stores/account';
  import { paginationInfo as paginationStore } from '$stores/relayerApi';

  import Transaction from './Transaction.svelte';

  const log = getLogger('Transactions.svelte');

  export const transactions = writable<BridgeTransaction[]>([]);

  const relayerApi = new RelayerAPIService(PUBLIC_RELAYER_URL);

  let pageSize = 3;
  let currentPage = 1;
  let totalItems = 0;
  let loadingTxs = true;
  let isBlurred = false;

  const handlePageChange = (detail: number) => {
    isBlurred = true;
    setTimeout(() => {
      currentPage = detail;
      isBlurred = false;
    }, 220);
  };

  onMount(async () => {
    if (!$account?.isConnected) {
      loadingTxs = false;
      return;
    }
    await fetchTransactions();
  });

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

  function getTransactionsToShow(page: number, pageSize: number, bridgeTx: BridgeTransaction[]) {
    const start = (page - 1) * pageSize;
    const end = start + pageSize;

    return bridgeTx.slice(start, end);
  }

  $: transactionsToShow = getTransactionsToShow(currentPage, pageSize, $transactions);

  $: if ($paginationStore) {
    totalItems = $transactions.length;
  }

  function onWalletConnect() {
    web3modal.openModal();
  }

  const onAccountChange = async (newAccount: Account, oldAccount?: Account) => {
    if (newAccount?.isConnected) {
      await fetchTransactions();
    }
  };
</script>

<div class="flex flex-col justify-center w-full">
  <Card class="md:min-w-[524px]" title={$t('activities.title')} text={$t('activities.description')}>
    <div class="flex flex-col" style={`min-height: calc(${pageSize} * 80px);`}>
      <div class="h-sep" />
      <div class="flex text-white">
        <div class="w-1/5 px-4 py-2">{$t('activities.header.from')}</div>
        <div class="w-1/5 px-4 py-2">{$t('activities.header.to')}</div>
        <div class="w-1/5 px-4 py-2">{$t('activities.header.amount')}</div>
        <div class="w-1/5 px-4 py-2">{$t('activities.header.status')}</div>
        <div class="w-1/5 px-4 py-2">{$t('activities.header.explorer')}</div>
      </div>
      <div class="h-sep" />
      {#if transactionsToShow.length && !loadingTxs && $account?.isConnected}
        <div
          class="flex flex-col items-center justify-center {isBlurred ? 'blur' : ''}"
          style={`min-height: calc(${pageSize - 1} * 80px);`}>
          {#each transactionsToShow as item (item.hash)}
            <Transaction {item} />
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
<OnAccount change={onAccountChange} />

<style>
  .blur {
    filter: blur(5px);
    transition: filter 0.1s ease-in-out;
  }
</style>
