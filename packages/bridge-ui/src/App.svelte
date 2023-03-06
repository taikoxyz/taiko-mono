<script lang="ts">
  import { wrap } from 'svelte-spa-router/wrap';
  import QueryProvider from './components/providers/QueryProvider.svelte';
  import Router from 'svelte-spa-router';
  import { SvelteToast } from '@zerodevx/svelte-toast';
  import type { SvelteToastOptions } from '@zerodevx/svelte-toast';

  import Home from './pages/home/Home.svelte';
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

  setupI18n({ withLocale: 'en' });

  import SwitchEthereumChainModal from './components/modals/SwitchEthereumChainModal.svelte';
  import { setProviders } from './store/providers';
  import HeaderAnnouncement from './components/HeaderAnnouncement.svelte';
  import { setTokenService } from './store/userToken';
  import { setRelayer } from './store/relayerApi';

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

  const toastOptions: SvelteToastOptions = {
    dismissable: false,
    duration: 4000,
    pausable: false,
  };

  const routes = {
    '/': wrap({
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
    font-family: 'Inter', sans-serif;
  }
</style>
