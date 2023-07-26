<script lang="ts">
  import { mainnet, sepolia } from '@wagmi/core';
  import { t } from 'svelte-i18n';
  import { formatEther } from 'viem';

  import Amount from '$components/Bridge/Amount.svelte';
  import { Card } from '$components/Card';
  import { EthIcon, TaikoIcon } from '$components/Icon';
  import { PUBLIC_RELAYER_URL } from '$env/static/public';
  import { taikoChain } from '$libs/chain';
  import type { BridgeTransaction, TxUIStatus } from '$libs/relayer/relayerApi';
  import { RelayerAPIService } from '$libs/relayer/RelayerAPIService';
  import { account } from '$stores/account';

  let poller: string | number | NodeJS.Timeout | undefined;
  const relayerApi = new RelayerAPIService(PUBLIC_RELAYER_URL);

  let tx: BridgeTransaction[] = [];

  const setupPoller = () => {
    if (poller) {
      clearInterval(poller);
    }
    poller = setInterval(doPoll(), 2000);
  };

  const doPoll = () => async () => {
    let address = $account.address;
    if (!address) {
      return;
    }
    const { txs, paginationInfo } = await relayerApi.getAllBridgeTransactionByAddress(address, {
      page: 0,
      size: 100,
    });

    tx = txs;
  };

  const explorerURL = 'https://explorer.example.com/tx';

  const mapStatusToText = (status: TxUIStatus) => {
    switch (status) {
      case 1:
        return 'Pending';
      case 2:
        return 'Claimed';
      case 3:
        return 'Failed';
      default:
        return 'Unknown';
    }
  };

  $: setupPoller();
</script>

<Card class="md:min-w-[524px] " title={$t('activities.title')} text={$t('activities.description')}>
  <div class="flex flex-col w-full">
    <div class="flex text-white">
      <div class="w-1/5 px-4 py-2">From</div>
      <div class="w-1/5 px-4 py-2">To</div>
      <div class="w-1/5 px-4 py-2">Amount</div>
      <div class="w-1/5 px-4 py-2">Status</div>
      <div class="w-1/5 px-4 py-2">Explorer</div>
    </div>
    <div class="flex flex-col">
      {#each tx as item (item.hash)}
        <div class="flex text-white h-[80px]">
          <div class="w-1/5 px-4 py-2 flex flex-col justify-center items-stretch">
            {#if Number(item.srcChainId) === sepolia.id}
              <div class="f-items-center space-x-2">
                <i role="img" aria-label="Ethereum">
                  <EthIcon size={20} />
                </i>
                <span>Sepolia</span>
              </div>
            {:else if Number(item.srcChainId) === taikoChain.id}
              <div class="f-items-center space-x-2">
                <i role="img" aria-label="Taiko">
                  <TaikoIcon size={20} />
                </i>
                <span>Taiko</span>
              </div>
            {:else}
              {item.srcChainId}
            {/if}
          </div>
          <div class="w-1/5 px-4 py-2 flex flex-col justify-center items-stretch">
            {#if Number(item.destChainId) === sepolia.id}
              <div class="f-items-center space-x-2">
                <i role="img" aria-label="Ethereum">
                  <EthIcon size={20} />
                </i>
                <span>Sepolia</span>
              </div>
            {:else if Number(item.destChainId) === taikoChain.id}
              <div class="f-items-center space-x-2">
                <i role="img" aria-label="Taiko">
                  <TaikoIcon size={20} />
                </i>
                <span>Taiko</span>
              </div>
            {:else}
              item.destChainId
            {/if}
          </div>
          <div class="w-1/5 px-4 py-2 flex flex-col justify-center items-stretch">
            {formatEther(item.amount ? item.amount : BigInt(0))}
            {item.symbol}
          </div>
          <div class="w-1/5 px-4 py-2 flex flex-col justify-center items-stretch">
            {mapStatusToText(item.status)}
          </div>
          <div class="w-1/5 px-4 py-2 flex flex-col justify-center items-stretch">
            <a href={`${explorerURL}/${item.hash}`} target="_blank"> View on Explorer </a>
          </div>
        </div>
      {/each}
    </div>
  </div>
</Card>
