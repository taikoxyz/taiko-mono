<script lang="ts">
  import { onDestroy } from "svelte";
  import { BigNumber, ethers } from "ethers";
  import { signer } from "../../store/signer";
  import { _ } from "svelte-i18n";
  import {
    connect as wagmiConnect,
    Connector,
    fetchSigner,
    watchAccount,
    watchNetwork,
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
  import { transactioner, transactions } from "../../store/transactions";
  import WalletConnect from "../icons/WalletConnect.svelte";
  import CoinbaseWallet from "../icons/CoinbaseWallet.svelte";

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

  let unwatchNetwork;
  let unwatchAccount;

  async function setSigner() {
    const wagmiSigner = await fetchSigner();
    signer.set(wagmiSigner);
    return wagmiSigner;
  }

  async function connectWithConnector(connector: Connector) {
    const { chain } = await wagmiConnect({ connector });
    await setSigner();
    await changeChain(chain.id);
    unwatchNetwork = watchNetwork(
      async (network) => await changeChain(network.chain.id)
    );
    unwatchAccount = watchAccount(async () => {
      const s = await setSigner();
      transactions.set(
        await $transactioner.GetAllByAddress(await s.getAddress())
      );
    });
    successToast("Connected");
  }

  const iconMap = {
    metamask: MetaMask,
    walletconnect: WalletConnect,
    "coinbase wallet": CoinbaseWallet,
  };

  onDestroy(() => {
    if (unwatchNetwork) {
      unwatchNetwork();
    }
    if (unwatchAccount) {
      unwatchAccount();
    }
  });
</script>

<button
  class="btn btn-md md:btn-wide"
  on:click={() => ($isConnectWalletModalOpen = true)}
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
