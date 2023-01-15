<script lang="ts">
  import { wrap } from "svelte-spa-router/wrap";
  import QueryProvider from "./components/providers/QueryProvider.svelte";
  import Router from "svelte-spa-router";
  import { SvelteToast } from "@zerodevx/svelte-toast";
  import type { SvelteToastOptions } from "@zerodevx/svelte-toast";
  import {
    configureChains,
    createClient,
  } from "@wagmi/core";
  import { publicProvider } from "@wagmi/core/providers/public";
  import { jsonRpcProvider } from "@wagmi/core/providers/jsonRpc";
  import { CoinbaseWalletConnector } from "@wagmi/core/connectors/coinbaseWallet";
  import { WalletConnectConnector } from "@wagmi/core/connectors/walletConnect";
  import { MetaMaskConnector } from '@wagmi/core/connectors/metaMask'

  import Home from "./pages/home/Home.svelte";
  import { setupI18n } from "./i18n";
  import { BridgeType } from "./domain/bridge";
  import ETHBridge from "./eth/bridge";
  import { bridges, chainIdToTokenVaultAddress } from "./store/bridge";
  import ERC20Bridge from "./erc20/bridge";
  import {
    pendingTransactions,
    transactioner,
    transactions,
  } from "./store/transactions";
  import Navbar from "./components/Navbar.svelte";
  import { signer } from "./store/signer";
  import type { Transactioner } from "./domain/transactions";
  import { wagmiClient } from "./store/wagmi";

  setupI18n({ withLocale: "en" });
  import {
    chains,
    CHAIN_ID_MAINNET,
    CHAIN_ID_TAIKO,
    CHAIN_MAINNET,
    CHAIN_TKO,
    mainnet,
    taiko,
  } from "./domain/chain";
  import SwitchEthereumChainModal from "./components/modals/SwitchEthereumChainModal.svelte";
  import { ProofService } from "./proof/service";
  import { ethers } from "ethers";
  import type { Prover } from "./domain/proof";
  import { successToast } from "./utils/toast";
  import { StorageService } from "./storage/service";
  import { MessageStatus } from "./domain/message";
  import BridgeABI from "./constants/abi/Bridge";
  import { providers } from "./store/providers";
  import HeaderAnnouncement from "./components/HeaderAnnouncement.svelte";

  const providerMap: Map<number, ethers.providers.JsonRpcProvider> = new Map<
    number,
    ethers.providers.JsonRpcProvider
  >();

  providerMap.set(
    CHAIN_ID_MAINNET,
    new ethers.providers.JsonRpcProvider(import.meta.env.VITE_L1_RPC_URL)
  );
  providerMap.set(
    CHAIN_ID_TAIKO,
    new ethers.providers.JsonRpcProvider(import.meta.env.VITE_L2_RPC_URL)
  );
  providers.set(providerMap);

  const {
    chains: wagmiChains,
    provider,
  } = configureChains(
    [mainnet, taiko],
    [
      publicProvider(),
      jsonRpcProvider({
        rpc: (chain) => ({
          http: providerMap.get(chain.id).connection.url,
        }),
      }),
    ]
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
          appName: "Taiko Bridge",
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

  providers.set(providerMap);

  const prover: Prover = new ProofService(providerMap);

  const ethBridge = new ETHBridge(prover);
  const erc20Bridge = new ERC20Bridge(prover);

  bridges.update((store) => {
    store.set(BridgeType.ETH, ethBridge);
    store.set(BridgeType.ERC20, erc20Bridge);
    return store;
  });

  chainIdToTokenVaultAddress.update((store) => {
    store.set(CHAIN_TKO.id, import.meta.env.VITE_TAIKO_TOKEN_VAULT_ADDRESS);
    store.set(
      CHAIN_MAINNET.id,
      import.meta.env.VITE_MAINNET_TOKEN_VAULT_ADDRESS
    );
    return store;
  });

  const storageTransactioner: Transactioner = new StorageService(
    window.localStorage,
    providerMap
  );

  transactioner.set(storageTransactioner);

  signer.subscribe(async (store) => {
    if (store) {
      const txs = await $transactioner.GetAllByAddress(
        await store.getAddress()
      );

      transactions.set(txs);
    }
    return store;
  });

  pendingTransactions.subscribe((store) => {
    store.forEach(async (tx) => {
      await $signer.provider.waitForTransaction(tx.hash, 1);
      successToast("Transaction completed!");
      const s = store;
      s.pop();
      pendingTransactions.set(s);

      transactions.set(
        await $transactioner.GetAllByAddress(await $signer.getAddress())
      );
    });
  });

  const transactionToIntervalMap = new Map();

  transactions.subscribe((store) => {
    if (store) {
      store.forEach(async (tx) => {
        const txInterval = transactionToIntervalMap.get(tx.ethersTx.hash);
        if (txInterval) {
          clearInterval(txInterval);
          transactionToIntervalMap.delete(tx.ethersTx.hash);
        }

        if (tx.status === MessageStatus.New) {
          const provider = providerMap.get(tx.toChainId);

          
          const interval = setInterval(async () => {
            const txInterval = transactionToIntervalMap.get(tx.ethersTx.hash);
            if (txInterval !== interval) {
              clearInterval(txInterval);
              transactionToIntervalMap.delete(tx.ethersTx.hash);
            }

            transactionToIntervalMap.set(tx.ethersTx.hash, interval);
            if (!tx.signal) return;

            const contract = new ethers.Contract(
              chains[tx.toChainId].bridgeAddress,
              BridgeABI,
              provider
            );

            const messageStatus: MessageStatus =
              await contract.getMessageStatus(tx.signal);

            if (messageStatus === MessageStatus.Done) {
              successToast("Bridge message processed successfully");
              const txOngoingInterval = transactionToIntervalMap.get(tx.ethersTx.hash);
              clearInterval(txOngoingInterval);
              transactionToIntervalMap.delete(tx.ethersTx.hash);
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
    "/": wrap({
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
  @tailwind base;
  @tailwind components;
  @tailwind utilities;

  main {
    font-family: "Inter", sans-serif;
  }
</style>
