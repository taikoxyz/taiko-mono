<script lang="ts">
  import { sepolia } from '@wagmi/core';
  import { onMount } from 'svelte';
  import { writable } from 'svelte/store';
  import { t } from 'svelte-i18n';

  import { Button } from '$components/Button';
  import { Card } from '$components/Card';
  import { Paginator } from '$components/Paginator';
  import { Spinner } from '$components/Spinner';
  import { PUBLIC_RELAYER_URL } from '$env/static/public';
  import type { BridgeTransaction } from '$libs/bridge';
  import { web3modal } from '$libs/connect';
  import { RelayerAPIService } from '$libs/relayer/RelayerAPIService';
  import { account } from '$stores/account';
  import { paginationInfo as paginationStore } from '$stores/relayerApi';

  import Transaction from './Transaction.svelte';

  export const transactions = writable<BridgeTransaction[]>([]);

  let poller: string | number | NodeJS.Timeout | undefined;
  const relayerApi = new RelayerAPIService(PUBLIC_RELAYER_URL);

  let pageSize = 3;
  let currentPage = 1;
  let totalItems = 0;
  let loadingTxs = true;

  onMount(() => {
    loadingTxs = false;
    if (!$account?.isConnected) {
      return;
    }
    loadingTxs = true;
    doPoll();
  });

  const setupPoller = () => {
    if (poller) {
      clearInterval(poller);
    }
    poller = setInterval(doPoll(), 6000);
  };

  const doPoll = () => async () => {
    loadingTxs = true;
    let address = $account.address;
    if (!address || totalItems > 0) {
      loadingTxs = false;
      return;
    }
    const { txs, paginationInfo } = await relayerApi.getAllBridgeTransactionByAddress(address, {
      page: 0,
      size: 100,
    });

    loadingTxs = false;
    $transactions = txs;
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

  $: setupPoller();
</script>

<div class="flex flex-col items-center justify-center w-full">
  <Card class="md:min-w-[524px]" title={$t('activities.title')} text={$t('activities.description')}>
    <div class="flex flex-col" style={`min-height: calc(${pageSize} * 150px);`}>
      <div class="h-sep" />
      <div class="flex text-white">
        <div class="w-1/5 px-4 py-2">{$t('activities.header.from')}</div>
        <div class="w-1/5 px-4 py-2">{$t('activities.header.to')}</div>
        <div class="w-1/5 px-4 py-2">{$t('activities.header.amount')}</div>
        <div class="w-1/5 px-4 py-2">{$t('activities.header.status')}</div>
        <div class="w-1/5 px-4 py-2">{$t('activities.header.explorer')}</div>
      </div>
      <div class="h-sep" />
      <div class="flex flex-col items-center justify-center" style={`min-height: calc(${pageSize - 1} * 80px);`}>
        {#if transactionsToShow.length && !loadingTxs}
          {#each transactionsToShow as item (item.hash)}
            <Transaction {item} />
          {/each}
        {/if}
      </div>
      <div class="flex items-center justify-center text-white h-[80px]">
        {#if loadingTxs && $account?.isConnected}
          <Spinner /> <span class="pl-3">{$t('common.loading')}...</span>
        {:else if !transactionsToShow.length && $account?.isConnected}
          <span class="pl-3">{$t('activities.no_transactions')}</span>
        {:else if !$account?.isConnected}
          <Button type="primary" on:click={onWalletConnect} class="px-[28px] py-[14px] ">
            <span class="body-bold">{$t('wallet.connect')}</span>
          </Button>
        {/if}
      </div>
    </div>
  </Card>

  <div class="flex justify-end pt-2">
    <Paginator {pageSize} {totalItems} on:pageChange={({ detail }) => (currentPage = detail)} />
  </div>
</div>
