<script lang="ts">
  import { wrap } from "svelte-spa-router/wrap";
  import QueryProvider from "./components/providers/QueryProvider.svelte";
  import Router from "svelte-spa-router";
  import { SvelteToast, toast } from "@zerodevx/svelte-toast";
  import type { SvelteToastOptions } from "@zerodevx/svelte-toast";

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

  setupI18n({ withLocale: "en" });
  import { chains, CHAIN_MAINNET, CHAIN_TKO } from "./domain/chain";
  import SwitchEthereumChainModal from "./components/modals/SwitchEthereumChainModal.svelte";
  import { ProofService } from "./proof/service";
  import { ethers } from "ethers";
  import type { Prover } from "./domain/proof";
  import { successToast } from "./utils/toast";
  import { StorageService } from "./storage/service";
  import { MessageStatus } from "./domain/message";
  import BridgeABI from "./constants/abi/Bridge";

  const providerMap: Map<number, ethers.providers.JsonRpcProvider> = new Map<
    number,
    ethers.providers.JsonRpcProvider
  >();
  providerMap.set(
    CHAIN_MAINNET.id,
    new ethers.providers.JsonRpcProvider(import.meta.env.VITE_L1_RPC_URL)
  );
  providerMap.set(
    CHAIN_TKO.id,
    new ethers.providers.JsonRpcProvider(import.meta.env.VITE_L2_RPC_URL)
  );

  const prover: Prover = new ProofService(providerMap);

  const ethBridge = new ETHBridge(prover);
  const erc20Bridge = new ERC20Bridge(prover);

  bridges.update((store) => {
    store.set(BridgeType.ETH, ethBridge);
    store.set(BridgeType.ERC20, erc20Bridge);
    return store;
  });

  chainIdToTokenVaultAddress.update((store) => {
    store.set(CHAIN_TKO.id, import.meta.env.VITE_TAIKO_BRIDGE_ADDRESS);
    store.set(CHAIN_MAINNET.id, import.meta.env.VITE_MAINNET_BRIDGE_ADDRESS);
    return store;
  });

  // const relayerURL = import.meta.env.VITE_RELAYER_URL;

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

  transactions.subscribe((store) => {
    if (store) {
      store.forEach(async (tx) => {
        if (tx.interval) clearInterval(tx.interval);

        if (tx.status === MessageStatus.New) {
          const provider = providerMap.get(tx.message.destChainId.toNumber());

          const interval = setInterval(async () => {
            tx.interval = interval;
            const contract = new ethers.Contract(
              chains[tx.message.destChainId.toNumber()].bridgeAddress,
              BridgeABI,
              provider
            );

            const messageStatus: MessageStatus =
              await contract.getMessageStatus(tx.signal);

            if (messageStatus === MessageStatus.Done) {
              successToast("Bridge message processed successfully");
              clearInterval(tx.interval);
            }
          }, 30 * 1000);
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
    margin: 0;
    font-family: "Inter", sans-serif;
  }
</style>
