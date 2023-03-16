<script lang="ts">
  import { wrap } from 'svelte-spa-router/wrap';
  import QueryProvider from './components/providers/QueryProvider.svelte';
  import Router from 'svelte-spa-router';
  import { SvelteToast } from '@zerodevx/svelte-toast';
  import type { SvelteToastOptions } from '@zerodevx/svelte-toast';
  import { configureChains, createClient } from '@wagmi/core';
  import { publicProvider } from '@wagmi/core/providers/public';
  import { jsonRpcProvider } from '@wagmi/core/providers/jsonRpc';
  import { CoinbaseWalletConnector } from '@wagmi/core/connectors/coinbaseWallet';
  import { WalletConnectConnector } from '@wagmi/core/connectors/walletConnect';
  import { MetaMaskConnector } from '@wagmi/core/connectors/metaMask';

  import Home from './pages/home/Home.svelte';
  import { setupI18n } from './i18n';
  import { BridgeType } from './domain/bridge';
  import { ETHBridge } from './bridge/ETHBridge';
  import { ERC20Bridge } from './bridge/ERC20Bridge';
  import { bridges, chainIdToTokenVaultAddress } from './store/bridge';
  import {
    pendingTransactions,
    transactioner,
    transactions,
  } from './store/transactions';
  import Navbar from './components/Navbar.svelte';
  import { signer } from './store/signer';
  import type { BridgeTransaction, Transactioner } from './domain/transactions';
  import { wagmiClient } from './store/wagmi';

  setupI18n({ withLocale: 'en' });
  import SwitchEthereumChainModal from './components/modals/SwitchEthereumChainModal.svelte';
  import { ProofService } from './proof/ProofService';
  import { ethers } from 'ethers';
  import type { Prover } from './domain/proof';
  import { successToast } from './utils/toast';
  import { StorageService } from './storage/StorageService';
  import { MessageStatus } from './domain/message';
  import BridgeABI from './constants/abi/Bridge';
  import { providers } from './store/providers';
  import HeaderAnnouncement from './components/HeaderAnnouncement.svelte';
  import type { TokenService } from './domain/token';
  import { CustomTokenService } from './storage/CustomTokenService';
  import { userTokens, tokenService } from './store/userToken';
  import { RelayerAPIService } from './relayer-api/RelayerAPIService';
  import type { RelayerAPI } from './domain/relayerApi';
  import { relayerApi, relayerBlockInfoMap } from './store/relayerApi';
  import {
    L1_CHAIN_ID,
    L1_TOKEN_VAULT_ADDRESS,
    L2_CHAIN_ID,
    L2_TOKEN_VAULT_ADDRESS,
  } from './constants/envVars';
  import {
    chainsRecord,
    mainnetWagmiChain,
    taikoWagmiChain,
  } from './chain/chains';

  const providerMap = new Map<number, ethers.providers.JsonRpcProvider>();

  providerMap.set(
    L1_CHAIN_ID,
    new ethers.providers.JsonRpcProvider(import.meta.env.VITE_L1_RPC_URL),
  );
  providerMap.set(
    L2_CHAIN_ID,
    new ethers.providers.JsonRpcProvider(import.meta.env.VITE_L2_RPC_URL),
  );
  providers.set(providerMap);

  const { chains: wagmiChains, provider } = configureChains(
    [mainnetWagmiChain, taikoWagmiChain],
    [
      publicProvider(),
      jsonRpcProvider({
        rpc: (chain) => ({
          http: providerMap.get(chain.id).connection.url,
        }),
      }),
    ],
  );

  $wagmiClient = createClient({
    autoConnect: true,
    provider,
    connectors: [
      new MetaMaskConnector({
        chains: wagmiChains,
      }),
      new CoinbaseWalletConnector({
        chains: wagmiChains,
        options: {
          appName: 'Taiko Bridge',
        },
      }),
      new WalletConnectConnector({
        chains: wagmiChains,
        options: {
          qrcode: true,
        },
      }),
    ],
  });

  const prover: Prover = new ProofService(providerMap);

  const ethBridge = new ETHBridge(prover);
  const erc20Bridge = new ERC20Bridge(prover);

  bridges.update((store) => {
    store.set(BridgeType.ETH, ethBridge);
    store.set(BridgeType.ERC20, erc20Bridge);
    return store;
  });

  chainIdToTokenVaultAddress.update((store) => {
    store.set(L2_CHAIN_ID, L2_TOKEN_VAULT_ADDRESS);
    store.set(L1_CHAIN_ID, L1_TOKEN_VAULT_ADDRESS);
    return store;
  });

  const storageTransactioner: Transactioner = new StorageService(
    window.localStorage,
    providerMap,
  );

  const relayerApiService: RelayerAPI = new RelayerAPIService(
    providerMap,
    import.meta.env.VITE_RELAYER_URL,
  );

  const tokenStore: TokenService = new CustomTokenService(window.localStorage);

  tokenService.set(tokenStore);

  transactioner.set(storageTransactioner);
  relayerApi.set(relayerApiService);

  signer.subscribe(async (store) => {
    if (store) {
      const userAddress = await store.getAddress();

      const apiTxs = await $relayerApi.GetAllByAddress(userAddress);

      const blockInfoMap = await $relayerApi.GetBlockInfo();
      relayerBlockInfoMap.set(blockInfoMap);

      const txs = await $transactioner.GetAllByAddress(userAddress);

      // const hashToApiTxsMap = new Map(apiTxs.map((tx) => {
      //   return [tx.hash, tx];
      // }))

      // const updatedStorageTxs: BridgeTransaction[] = txs.filter((tx) => {
      //   if (apiTxs.find((apiTx) => apiTx.hash.toLowerCase() === tx.hash)) {
      //     return false;
      //   }
      //   return true;
      // });

      const updatedStorageTxs: BridgeTransaction[] = txs.filter((tx) => {
        const blockInfo = blockInfoMap.get(tx.fromChainId);
        if (blockInfo?.latestProcessedBlock >= tx.receipt.blockNumber) {
          return false;
        }
        return true;
      });

      $transactioner.UpdateStorageByAddress(userAddress, updatedStorageTxs);

      transactions.set([...updatedStorageTxs, ...apiTxs]);

      const tokens = await $tokenService.GetTokens(userAddress);
      userTokens.set(tokens);
    }
  });

  pendingTransactions.subscribe((store) => {
    (async () => {
      const confirmedPendingTxIndex = await Promise.race(
        store.map((tx, index) => {
          return new Promise<number>(async (resolve) => {
            await $signer.provider.waitForTransaction(tx.hash, 1);
            resolve(index);
          });
        }),
      );
      successToast('Transaction completed!');
      let s = store;
      s = s.slice(confirmedPendingTxIndex, 0);
      pendingTransactions.set(s);
    })();
  });

  const transactionToIntervalMap = new Map();

  transactions.subscribe((store) => {
    if (store) {
      store.forEach(async (tx) => {
        const txInterval = transactionToIntervalMap.get(tx.hash);
        if (txInterval) {
          clearInterval(txInterval);
          transactionToIntervalMap.delete(tx.hash);
        }

        if (tx.status === MessageStatus.New) {
          const provider = providerMap.get(tx.toChainId);

          const interval = setInterval(async () => {
            const txInterval = transactionToIntervalMap.get(tx.hash);
            if (txInterval !== interval) {
              clearInterval(txInterval);
              transactionToIntervalMap.delete(tx.hash);
            }

            transactionToIntervalMap.set(tx.hash, interval);
            if (!tx.msgHash) return;

            const contract = new ethers.Contract(
              chainsRecord[tx.toChainId].bridgeAddress,
              BridgeABI,
              provider,
            );

            const messageStatus: MessageStatus =
              await contract.getMessageStatus(tx.msgHash);

            if (messageStatus === MessageStatus.Done) {
              successToast('Bridge message processed successfully');
              const txOngoingInterval = transactionToIntervalMap.get(tx.hash);
              clearInterval(txOngoingInterval);
              transactionToIntervalMap.delete(tx.hash);
            }
          }, 20 * 1000);
        }
      });
    }
  });

  const toastOptions: SvelteToastOptions = {
    dismissable: false,
    duration: 4000,
    pausable: false,
  };

  const routes = {
    '/:tab?': wrap({
      component: Home,
      props: {},
      userData: {},
    }),
  };
</script>

<QueryProvider>
  <main>
    <HeaderAnnouncement />
    <Navbar />
    <Router {routes} />
  </main>
  <SvelteToast options={toastOptions} />
  <SwitchEthereumChainModal />
</QueryProvider>

<style global lang="postcss">
  main {
    font-family: 'Inter', sans-serif;
  }
</style>
