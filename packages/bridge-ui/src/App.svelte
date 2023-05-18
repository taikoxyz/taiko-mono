<script lang="ts">
  import QueryProvider from './components/providers/QueryProvider.svelte';

  import { transactions } from './store/transactions';
  import Navbar from './components/Navbar.svelte';
  import Toast from './components/Toast.svelte';
  import { signer } from './store/signer';
  // import type { BridgeTransaction } from './domain/transactions';

  import SwitchEthereumChainModal from './components/modals/SwitchEthereumChainModal.svelte';
  import { ethers } from 'ethers';
  import { MessageStatus } from './domain/message';
  import { bridgeABI } from './constants/abi';
  import { userTokens } from './store/userToken';
  // import { RelayerAPIService } from './relayer-api/RelayerAPIService';
  // import {
  //   DEFAULT_PAGE,
  //   MAX_PAGE_SIZE,
  //   type RelayerAPI,
  // } from './domain/relayerApi';
  // import {
  //   paginationInfo,
  //   relayerApi,
  //   relayerBlockInfoMap,
  // } from './store/relayerApi';
  import { chains } from './chain/chains';
  import { providers } from './provider/providers';
  // import { RELAYER_URL } from './constants/envVars';
  import Router from './components/Router.svelte';
  import { storageService, tokenService } from './storage/services';
  import { startWatching, stopWatching } from './wagmi/watcher';
  import { onDestroy, onMount } from 'svelte';
  import { getLogger } from './utils/logger';

  const log = getLogger('component:App');

  // const relayerApiService: RelayerAPI = new RelayerAPIService(
  //   RELAYER_URL,
  //   providers,
  // );

  // relayerApi.set(relayerApiService);

  signer.subscribe(async (newSigner) => {
    if (newSigner) {
      const userAddress = await newSigner.getAddress();

      // TODO: uncomment when relayer is ready

      // const { txs: apiTxs, paginationInfo: info } =
      //   await $relayerApi.getAllBridgeTransactionByAddress(userAddress, {
      //     page: DEFAULT_PAGE,
      //     size: MAX_PAGE_SIZE,
      //   });

      // paginationInfo.set(info);

      // const blockInfoMap = await $relayerApi.getBlockInfo();
      // relayerBlockInfoMap.set(blockInfoMap);

      const txs = await storageService.getAllByAddress(userAddress);

      // const hashToApiTxsMap = new Map(
      //   apiTxs.map((tx) => {
      //     return [tx.hash.toLowerCase(), 1];
      //   }),
      // );

      // const updatedStorageTxs: BridgeTransaction[] = txs.filter((tx) => {
      //   return !hashToApiTxsMap.has(tx.hash.toLowerCase());
      // });

      // storageService.updateStorageByAddress(userAddress, updatedStorageTxs);

      transactions.set([.../* updatedStorageTxs*/ txs /*, ...apiTxs*/]);

      const tokens = tokenService.getTokens(userAddress);
      userTokens.set(tokens);
    }
  });

  onMount(startWatching);
  onDestroy(stopWatching);
</script>

<QueryProvider>
  <main>
    <Navbar />
    <Router />
  </main>
  <Toast />
  <SwitchEthereumChainModal />
</QueryProvider>

<style>
  main {
    font-family: 'Inter', sans-serif;
  }
</style>
