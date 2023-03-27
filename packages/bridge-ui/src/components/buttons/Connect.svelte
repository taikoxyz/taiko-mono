<script lang="ts">
  import { onMount } from 'svelte';
  import { signer } from '../../store/signer';
  import { _ } from 'svelte-i18n';
  import {
    connect as wagmiConnect,
    Connector,
    fetchSigner,
    watchAccount,
    watchNetwork,
    ConnectorNotFoundError,
    getNetwork,
    getAccount,
  } from '@wagmi/core';

  import { fromChain, toChain } from '../../store/chain';
  import { isSwitchEthereumChainModalOpen } from '../../store/modal';
  import Modal from '../modals/Modal.svelte';
  import { wagmiClient } from '../../store/wagmi';
  import MetaMask from '../icons/MetaMask.svelte';
  import WalletConnect from '../icons/WalletConnect.svelte';
  import CoinbaseWallet from '../icons/CoinbaseWallet.svelte';
  import { transactioner, transactions } from '../../store/transactions';
  import { mainnetChain, taikoChain } from '../../chain/chains';
  import { errorToast, successToast } from '../Toast.svelte';

  export let isConnectWalletModalOpen = false;

  const changeChain = (chainId: number) => {
    if (chainId === taikoChain.id) {
      fromChain.set(taikoChain);
      toChain.set(mainnetChain);
    } else if (chainId === mainnetChain.id) {
      fromChain.set(mainnetChain);
      toChain.set(taikoChain);
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

    changeChain(chain.id);

    watchNetwork((network) => {
      if (network.chain?.id) {
        changeChain(network.chain.id);
      }
    });

    watchAccount(async () => {
      const wagmiSigner = await setSigner();
      if (wagmiSigner) {
        const signerAddress = await wagmiSigner.getAddress();
        const signerTransactions = await $transactioner.getAllByAddress(
          signerAddress,
        );
        transactions.set(signerTransactions);
      }
    });
  }

  async function connectWithConnector(connector: Connector) {
    try {
      await wagmiConnect({ connector });
      await onConnect();
      successToast('Connected');
    } catch (error) {
      if (error instanceof ConnectorNotFoundError) {
        errorToast(`${connector.name} not installed`);
      } else {
        errorToast('Error while connecting to wallet');
      }
    }
  }

  const iconMap = {
    metamask: MetaMask,
    walletconnect: WalletConnect,
    'coinbase wallet': CoinbaseWallet,
  };

  onMount(() => {
    const account = getAccount();
    if (account.isConnected) {
      (async () => {
        await onConnect();
      })();
    }
  });
</script>

<button class="btn btn-md" on:click={() => (isConnectWalletModalOpen = true)}>
  {$_('nav.connect')}
</button>

<Modal
  title={$_('connectModal.title')}
  isOpen={isConnectWalletModalOpen}
  onClose={() => (isConnectWalletModalOpen = false)}>
  <div class="flex flex-col items-center space-y-4 space-x-0 p-8">
    {#each $wagmiClient.connectors as connector}
      <button
        class="btn flex items-center justify-start md:pl-32 space-x-4 w-full"
        on:click={() => connectWithConnector(connector)}>
        <div class="h-7 w-7 flex items-center justify-center">
          <svelte:component this={iconMap[connector.name.toLowerCase()]} />
        </div>
        <span>{connector.name}</span>
      </button>
    {/each}
  </div>
</Modal>
