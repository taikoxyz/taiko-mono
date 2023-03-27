<script lang="ts">
  import { wrap } from 'svelte-spa-router/wrap';
  import Router from 'svelte-spa-router';
  import { configureChains, createClient } from '@wagmi/core';
  import { publicProvider } from '@wagmi/core/providers/public';
  import { jsonRpcProvider } from '@wagmi/core/providers/jsonRpc';
  import { CoinbaseWalletConnector } from '@wagmi/core/connectors/coinbaseWallet';
  import { WalletConnectConnector } from '@wagmi/core/connectors/walletConnect';
  import { MetaMaskConnector } from '@wagmi/core/connectors/metaMask';

  import Home from './pages/home/Home.svelte';
  import { pendingTransactions, transactions } from './store/transaction';
  import Navbar from './components/Navbar.svelte';
  import Toast, { successToast } from './components/Toast.svelte';
  import { signer } from './store/signer';
  import type { BridgeTransaction } from './domain/transaction';
  import { wagmiClient } from './store/wagmi';

  import SwitchEthereumChainModal from './components/modals/SwitchEthereumChainModal.svelte';
  import { ethers } from 'ethers';
  import { MessageStatus } from './domain/message';
  import BridgeABI from './constants/abi/Bridge';
  import { relayerBlockInfoMap } from './store/relayerApi';
  import { chains, mainnetWagmiChain, taikoWagmiChain } from './chain/chains';
  import { providers } from './provider/providers';
  import { storageService, tokenService } from './storage/services';
  import { userTokens } from './store/token';
  import { relayerApi } from './relayer-api/services';

  const { chains: wagmiChains, provider } = configureChains(
    [mainnetWagmiChain, taikoWagmiChain],
    [
      publicProvider(),
      jsonRpcProvider({
        rpc: (chain) => ({
          http: providers[chain.id].connection.url,
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

  signer.subscribe(async (store) => {
    if (store) {
      const userAddress = await store.getAddress();

      const apiTxs = await relayerApi.GetAllBridgeTransactionByAddress(
        userAddress,
      );
      const blockInfoMap = await relayerApi.GetBlockInfo();
      relayerBlockInfoMap.set(blockInfoMap);

      const txs = await storageService.GetAllByAddress(userAddress);
      const hashToApiTxsMap = new Map(
        apiTxs.map((tx) => {
          return [tx.hash.toLowerCase(), 1];
        }),
      );

      const updatedStorageTxs: BridgeTransaction[] = txs.filter((tx) => {
        return !hashToApiTxsMap.has(tx.hash.toLowerCase());
      });

      // const updatedStorageTxs: BridgeTransaction[] = txs.filter((tx) => {
      //   const blockInfo = blockInfoMap.get(tx.fromChainId);
      //   if (blockInfo?.latestProcessedBlock >= tx.receipt?.blockNumber) {
      //     return false;
      //   }
      //   return true;
      // });

      storageService.UpdateStorageByAddress(userAddress, updatedStorageTxs);

      transactions.set([...updatedStorageTxs, ...apiTxs]);

      const tokens = tokenService.GetTokens(userAddress);
      userTokens.set(tokens);
    }
  });

  pendingTransactions.subscribe((store) => {
    (async () => {
      const confirmedPendingTxIndex = await Promise.race(
        store.map((tx, index) => {
          return new Promise<number>((resolve) => {
            $signer.provider
              .waitForTransaction(tx.hash, 1)
              .then(() => resolve(index));
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
      store.forEach((tx) => {
        const txInterval = transactionToIntervalMap.get(tx.hash);
        if (txInterval) {
          clearInterval(txInterval);
          transactionToIntervalMap.delete(tx.hash);
        }

        if (tx.status === MessageStatus.New) {
          const provider = providers[tx.toChainId];

          const interval = setInterval(async () => {
            const txInterval = transactionToIntervalMap.get(tx.hash);
            if (txInterval !== interval) {
              clearInterval(txInterval);
              transactionToIntervalMap.delete(tx.hash);
            }

            transactionToIntervalMap.set(tx.hash, interval);
            if (!tx.msgHash) return;

            const contract = new ethers.Contract(
              chains[tx.toChainId].bridgeAddress,
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

  const routes = {
    '/:tab?': wrap({
      component: Home,
      props: {},
      userData: {},
    }),
  };
</script>

<main>
  <Navbar />
  <Router {routes} />
</main>

<Toast />

<SwitchEthereumChainModal />

<style>
  main {
    font-family: 'Inter', sans-serif;
  }
</style>
