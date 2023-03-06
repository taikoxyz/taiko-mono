<script lang="ts">
  import QueryProvider from './components/providers/QueryProvider.svelte';
  import Router from 'svelte-spa-router';
  import { SvelteToast } from '@zerodevx/svelte-toast';

  import { setupI18n } from './i18n';
  import { updateBridges } from './store/bridge';
  import {
    setTransactioner,
    subscribeToPendingTransactions,
    subscribeToTransactions,
  } from './store/transactions';
  import Navbar from './components/Navbar.svelte';
  import { subscribeToSigner } from './store/signer';
  import { setWagmiClient } from './store/wagmi';

  // TODO: I'm guessing we need this here becase it's used
  //       in SwitchEthereumChainModal, but I'm wondering
  //       of we can we run this setup somewhere else.
  setupI18n({ withLocale: 'en' });

  import SwitchEthereumChainModal from './components/modals/SwitchEthereumChainModal.svelte';
  import { setProviders } from './store/providers';
  import HeaderAnnouncement from './components/HeaderAnnouncement.svelte';
  import { setTokenService } from './store/userToken';
  import { setRelayer } from './store/relayerApi';
  import { routes, toastOptions } from './config';

  const { providerMap } = setProviders(
    import.meta.env.VITE_L1_RPC_URL,
    import.meta.env.VITE_L2_RPC_URL,
  );

  setWagmiClient(providerMap);

  updateBridges(
    providerMap,
    import.meta.env.VITE_MAINNET_TOKEN_VAULT_ADDRESS,
    import.meta.env.VITE_TAIKO_TOKEN_VAULT_ADDRESS,
  );

  const relayerApi = setRelayer(providerMap, import.meta.env.VITE_RELAYER_URL);

  const transitioner = setTransactioner(providerMap, globalThis.localStorage);

  const tokenService = setTokenService(globalThis.localStorage);

  const signer = subscribeToSigner($relayerApi, $transitioner, $tokenService);

  subscribeToPendingTransactions($signer, $transitioner);

  subscribeToTransactions(providerMap);
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
    font-family: 'Inter', sans-serif;
  }
</style>
