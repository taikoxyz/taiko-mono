<script lang="ts">
  import { onDestroy, onMount } from "svelte";
  import { signer } from "../../store/signer";
  import { _ } from "svelte-i18n";
  import {
    connect as wagmiConnect,
    Connector,
    fetchSigner,
    watchAccount,
    watchNetwork,
    ConnectorNotFoundError,
    getNetwork,
    getAccount
  } from "@wagmi/core";

  import { CHAIN_MAINNET, CHAIN_TKO } from "../../domain/chain";
  import { fromChain, toChain } from "../../store/chain";
  import {
    isSwitchEthereumChainModalOpen,
    isConnectWalletModalOpen,
  } from "../../store/modal";
  import { errorToast, successToast } from "../../utils/toast";
  import Modal from "../modals/Modal.svelte";
  import { wagmiClient } from "../../store/wagmi";
  import MetaMask from "../icons/MetaMask.svelte";
  import WalletConnect from "../icons/WalletConnect.svelte";
  import CoinbaseWallet from "../icons/CoinbaseWallet.svelte";
  import { transactioner, transactions } from "../../store/transactions";

  const changeChain = async (chainId: number) => {
    if (chainId === CHAIN_TKO.id) {
      fromChain.set(CHAIN_TKO);
      toChain.set(CHAIN_MAINNET);
    } else if (chainId === CHAIN_MAINNET.id) {
      fromChain.set(CHAIN_MAINNET);
      toChain.set(CHAIN_TKO);
    } else {
      isSwitchEthereumChainModalOpen.set(true);
    }
  };

  async function setSigner() {
    const wagmiSigner = await fetchSigner();
    signer.set(wagmiSigner);
    return wagmiSigner;
  }

  async function onConnect() {
    const { chain } = getNetwork();
    await setSigner();
    await changeChain(chain.id);
    watchNetwork(
      async (network) => await changeChain(network.chain.id)
    );
    watchAccount(async () => {
      const s = await setSigner();
      transactions.set(
        await $transactioner.GetAllByAddress(await s.getAddress())
      );
    });
  }

  async function connectWithConnector(connector: Connector) {
    try {
      await wagmiConnect({ connector });
      await onConnect();
      successToast("Connected");
    } catch(error) {
      if(error instanceof ConnectorNotFoundError) {
        errorToast(`${connector.name} not installed`);
      } else {
        errorToast(`Error while connecting to wallet`);
      }
    }
  }

  const iconMap = {
    metamask: MetaMask,
    walletconnect: WalletConnect,
    "coinbase wallet": CoinbaseWallet,
  };

  onMount(() => {
    const account = getAccount();
    if(account.isConnected) {
      (async () => {
        await onConnect();
      })();
    }
  });
</script>

<button class="btn btn-md" on:click={() => ($isConnectWalletModalOpen = true)}
  >{$_("nav.connect")}</button
>

<Modal
  title={$_("connectModal.title")}
  isOpen={$isConnectWalletModalOpen}
  onClose={() => ($isConnectWalletModalOpen = false)}
>
  <div class="flex flex-col items-center space-y-4 space-x-0 p-8">
    {#each $wagmiClient.connectors as connector}
      <button
        class="btn flex items-center justify-start md:pl-32 space-x-4 w-full"
        on:click={() => connectWithConnector(connector)}
      >
        <div class="h-7 w-7 flex items-center justify-center">
          <svelte:component this={iconMap[connector.name.toLowerCase()]} />
        </div>
        <span>{connector.name}</span>
      </button>
    {/each}
  </div>
</Modal>
