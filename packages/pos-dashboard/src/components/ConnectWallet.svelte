<script lang="ts">
  import * as Sentry from '@sentry/svelte';
  import { _ } from 'svelte-i18n';
  import {
    Connector,
    ConnectorNotFoundError,
    UserRejectedRequestError,
  } from 'wagmi';
  import { connect as wagmiConnect } from 'wagmi/actions';

  import { getLogger } from '../utils/logger';
  import { client as wagmiClient } from '../wagmi/client';
  import CoinbaseWallet from './icons/CoinbaseWallet.svelte';
  import MetaMask from './icons/MetaMask.svelte';
  import WalletConnect from './icons/WalletConnect.svelte';
  import Modal from './Modal.svelte';
  import {
    errorToast,
    successToast,
    warningToast,
  } from './NotificationToast.svelte';

  const log = getLogger('component:Connect');

  export let isConnectWalletModalOpen = false;

  async function connectWithConnector(connector: Connector) {
    if (wagmiClient.connector?.id !== connector.id) {
      try {
        log(`Connecting with connector "${connector.name}"`);

        const result = await wagmiConnect({ connector });

        log('Connected with result', result);

        successToast('Wallet connected!');
      } catch (error) {
        console.error(error);

        if (error instanceof ConnectorNotFoundError) {
          // I'm curious to know how often this happens
          Sentry.captureMessage(`${connector.name} not installed.`);

          errorToast(`${connector.name} not installed.`);
        } else if (error instanceof UserRejectedRequestError) {
          warningToast('Connect request canceled.');
        } else {
          Sentry.captureException(error);

          errorToast('Error connecting wallet');
        }
      }
    }
  }

  const iconMap = {
    metamask: MetaMask,
    walletconnect: WalletConnect,
    'coinbase wallet': CoinbaseWallet,
  };
</script>

<button class="btn" on:click={() => (isConnectWalletModalOpen = true)}>
  {$_('nav.connect')}
</button>

<Modal
  title={$_('connectModal.title')}
  isOpen={isConnectWalletModalOpen}
  onClose={() => (isConnectWalletModalOpen = false)}>
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
