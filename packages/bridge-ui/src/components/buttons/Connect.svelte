<script lang="ts">
  import { onMount } from 'svelte';
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
    Client,
    createClient,
    configureChains,
  } from '@wagmi/core';
  import { CoinbaseWalletConnector } from '@wagmi/core/connectors/coinbaseWallet';
  import { WalletConnectConnector } from '@wagmi/core/connectors/walletConnect';
  import { MetaMaskConnector } from '@wagmi/core/connectors/metaMask';
  import { publicProvider } from '@wagmi/core/providers/public';
  import { jsonRpcProvider } from '@wagmi/core/providers/jsonRpc';

  import { signer } from '../../store/signer';
  import {
    CHAIN_MAINNET,
    CHAIN_TKO,
    mainnet,
    taiko,
    providers,
  } from '../../domain/chain';
  import { fromChain, toChain } from '../../store/chain';
  import {
    isSwitchEthereumChainModalOpen,
    isConnectWalletModalOpen,
  } from '../../store/modal';
  import { errorToast, successToast } from '../../utils/toast';
  import Modal from '../modals/Modal.svelte';
  import MetaMask from '../icons/MetaMask.svelte';
  import WalletConnect from '../icons/WalletConnect.svelte';
  import CoinbaseWallet from '../icons/CoinbaseWallet.svelte';
  import { transactioner, transactions } from '../../store/transactions';

  const iconMap = {
    metamask: MetaMask,
    walletconnect: WalletConnect,
    'coinbase wallet': CoinbaseWallet,
  };

  const { chains, provider } = configureChains(
    [mainnet, taiko],
    [
      publicProvider(),
      jsonRpcProvider({
        rpc: (chain) => ({
          http: providers.get(chain.id).connection.url,
        }),
      }),
    ],
  );

  let wagmiClient: Client = createClient({
    autoConnect: true,
    provider,
    connectors: [
      new MetaMaskConnector({ chains }),
      new CoinbaseWalletConnector({
        chains,
        options: {
          appName: 'Taiko Bridge',
        },
      }),
      new WalletConnectConnector({
        chains,
        options: {
          qrcode: true,
        },
      }),
    ],
  });

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
    watchNetwork(async (network) => await changeChain(network.chain.id));
    watchAccount(async () => {
      const s = await setSigner();
      transactions.set(
        await $transactioner.GetAllByAddress(await s.getAddress()),
      );
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

  onMount(() => {
    const account = getAccount();
    if (account.isConnected) {
      // TODO: loading state
      (async () => {
        await onConnect();
      })();
    }
  });
</script>

<button class="btn btn-md" on:click={() => ($isConnectWalletModalOpen = true)}
  >{$_('nav.connect')}</button>

<Modal
  title={$_('connectModal.title')}
  isOpen={$isConnectWalletModalOpen}
  onClose={() => ($isConnectWalletModalOpen = false)}>
  <div class="flex flex-col items-center space-y-4 space-x-0 p-8">
    {#each wagmiClient.connectors as connector}
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
