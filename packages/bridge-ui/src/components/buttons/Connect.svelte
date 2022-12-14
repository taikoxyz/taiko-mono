<script lang="ts">
  import { onDestroy } from "svelte";
  import { BigNumber, ethers } from "ethers";
  import { signer } from "../../store/signer";
  import { _ } from "svelte-i18n";
  import { connect as wagmiConnect, Connector, fetchSigner, watchAccount, watchNetwork } from '@wagmi/core'

  import { CHAIN_MAINNET, CHAIN_TKO } from "../../domain/chain";
  import { fromChain, toChain } from "../../store/chain";
  import { ethereum } from "../../store/ethereum";
  import { isSwitchEthereumChainModalOpen, isConnectWalletModalOpen } from "../../store/modal";
  import { errorToast, successToast } from "../../utils/toast";
  import Modal from "../modals/Modal.svelte";
  import { wagmiClient } from "../../store/wagmi";
  import MetaMask from "../icons/MetaMask.svelte";


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

  async function connect() {
    try {
      const getAccounts = async () => {
        ethereum.set(window.ethereum);
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        await provider.send("eth_requestAccounts", []);

        signer.set(provider.getSigner());
      };

      await getAccounts();

      const { chainId } = await $signer.provider.getNetwork();

      await changeChain(chainId);

      window.ethereum.on("chainChanged", async (chainId) => {
        await changeChain(BigNumber.from(chainId).toNumber());
      });

      window.ethereum.on("accountsChanged", async (accounts) => {
        await getAccounts();
      });

      successToast("Connected");
    } catch (e) {
      console.log(e);
      errorToast("Error connecting to wallet");
    }
  }

  let unwatchNetwork;
  let unwatchAccount;

  async function setSigner() {
    const wagmiSigner = await fetchSigner();
    signer.set(wagmiSigner);
  }

  async function connectWithConnector(connector: Connector) {
    const { chain } = await wagmiConnect({ connector });
    await setSigner();
    await changeChain(chain.id);
    unwatchNetwork = watchNetwork(async (network) => await changeChain(network.chain.id));
    unwatchAccount = watchAccount(async () => await setSigner());
    ethereum.set(await connector.getProvider());
    successToast("Connected");
  }

  const iconMap = {
    'metamask': MetaMask,
  }

  onDestroy(() => {
    if(unwatchNetwork) {
      unwatchNetwork()
    }
    if(unwatchAccount) {
      unwatchAccount()
    }
  })
</script>

<button class="btn btn-md md:btn-wide" on:click={() => $isConnectWalletModalOpen = true}
  >{$_("nav.connect")}</button
>

<Modal
  title={$_("connectModal.title")}
  isOpen={$isConnectWalletModalOpen}
  onClose={() => $isConnectWalletModalOpen = false}
>
  <div class="flex items-center space-x-4 p-8">
    {#each $wagmiClient.connectors as connector}
      <button class="btn flex flex-col space-y-2" on:click={() => connectWithConnector(connector)}>
        <svelte:component this={iconMap[connector.name.toLowerCase()]} />
        <span>{connector.name}</span>
      </button>
    {/each}
  </div>
</Modal>
