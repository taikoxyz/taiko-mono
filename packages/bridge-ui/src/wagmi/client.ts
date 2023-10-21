import { type Chain, configureChains, createClient } from 'wagmi';
import { CoinbaseWalletConnector } from 'wagmi/connectors/coinbaseWallet';
import { MetaMaskConnector } from 'wagmi/connectors/metaMask';
import { WalletConnectConnector } from 'wagmi/connectors/walletConnect';
import { jsonRpcProvider } from 'wagmi/providers/jsonRpc';
import { publicProvider } from 'wagmi/providers/public';

import {
  L1_CHAIN_ID,
  L1_CHAIN_NAME,
  L1_EXPLORER_URL,
  L1_RPC,
  L2_CHAIN_ID,
  L2_CHAIN_NAME,
  L2_EXPLORER_URL,
  L2_RPC,
  WALLETCONNECT_PROJECT_ID,
} from '../constants/envVars';
import { providers } from '../provider/providers';
import { isMobileDevice } from '../utils/isMobileDevice';

export const mainnetWagmiChain: Chain = {
  id: L1_CHAIN_ID,
  name: L1_CHAIN_NAME,
  network: '',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: { http: [L1_RPC] },
    public: { http: [L1_RPC] },
  },
  blockExplorers: {
    default: {
      name: 'Main',
      url: L1_EXPLORER_URL,
    },
  },
};

export const taikoWagmiChain: Chain = {
  id: L2_CHAIN_ID,
  name: L2_CHAIN_NAME,
  network: '',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: { http: [L2_RPC] },
    public: { http: [L2_RPC] },
  },
  blockExplorers: {
    default: {
      name: 'Main',
      url: L2_EXPLORER_URL,
    },
  },
};

const { chains, provider } = configureChains(
  [mainnetWagmiChain, taikoWagmiChain],
  [
    publicProvider(),
    jsonRpcProvider({
      rpc: (chain) => ({
        http: providers[chain.id].connection.url,
      }),
    }),
  ],
);

export const client = createClient({
  autoConnect: true,
  provider,
  connectors: [
    !isMobileDevice() ? new MetaMaskConnector({ chains }) : null,
    new WalletConnectConnector({
      chains,
      options: {
        projectId: WALLETCONNECT_PROJECT_ID,
        showQrModal: true,
        qrModalOptions: {
          themeVariables: {
          // DaisyUI modal has a z-index of 999 by default
          // WalletConnect modal has a z-index of 89 by default
          // Let's increase wc to beat daisyui's modal
            '--wcm-z-index': '9999',
            '--wcm-background-color': '#E81899',

            // @ts-ignore
            // '--wcm-color-fg-1': '#E81899',
            '--wcm-accent-color': '#E81899',
          },
        },
      },
    }),
    new CoinbaseWalletConnector({
      chains,
      options: { appName: 'Taiko Bridge' },
    }),
  ].filter(Boolean), // remove nulls
});
