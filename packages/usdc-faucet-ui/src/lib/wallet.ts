import { injected, walletConnect } from '@wagmi/connectors';
import { createConfig, http, reconnect } from '@wagmi/core';
import { createWeb3Modal } from '@web3modal/wagmi';

import { browser } from '$app/environment';
import { hoodiChain } from '$lib/chains';
import { appConfig } from '$lib/config';

export const config = createConfig({
  chains: [hoodiChain],
  connectors: [walletConnect({ projectId: appConfig.walletConnectProjectId, showQrModal: false }), injected()],
  transports: {
    [hoodiChain.id]: http(hoodiChain.rpcUrls.default.http[0]),
  },
});

export const reconnectionPromise = browser ? reconnect(config) : Promise.resolve([]);

export const web3modal = browser
  ? createWeb3Modal({
      wagmiConfig: config,
      projectId: appConfig.walletConnectProjectId,
      featuredWalletIds: [],
      allowUnsupportedChain: true,
      excludeWalletIds: [],
      themeMode: 'light',
      themeVariables: {
        '--w3m-color-mix': '#f7efe2',
        '--w3m-color-mix-strength': 24,
        '--w3m-font-family': '"Avenir Next", "Segoe UI", sans-serif',
        '--w3m-border-radius-master': '18px',
        '--w3m-accent': '#005fd6',
      },
    })
  : null;
