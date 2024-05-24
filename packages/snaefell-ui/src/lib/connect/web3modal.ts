import { getAccount, getChainId, watchAccount, watchChainId } from '@wagmi/core';
import { createWeb3Modal } from '@web3modal/wagmi';
import { readable } from 'svelte/store';

import { PUBLIC_WALLETCONNECT_PROJECT_ID } from '$env/static/public';
import { config } from '$wagmi-config';

import { getChainImages } from '../../lib/chain';

const projectId = PUBLIC_WALLETCONNECT_PROJECT_ID || 'walletconnect-project-id';
const chainImages = getChainImages();

export const chainId = readable(getChainId(config), (set) => watchChainId(config, { onChange: set }));

export const account = readable(getAccount(config), (set) => watchAccount(config, { onChange: set }));

export const provider = readable<unknown | undefined>(undefined, (set) =>
  watchAccount(config, {
    onChange: async (account) => {
      if (!account.connector) return set(undefined);
      set(await account.connector?.getProvider());
    },
  }),
);

export const web3modal = createWeb3Modal({
  wagmiConfig: config || { projectId, chains: [], connectors: [] },
  projectId,
  featuredWalletIds: [],
  allowUnsupportedChain: true,
  excludeWalletIds: ['c57ca95b47569778a828d19178114f4db188b89b763c899ba0be274e97267d96'],
  chainImages,
  themeVariables: {
    '--w3m-color-mix': 'var(--neutral-background)',
    '--w3m-color-mix-strength': 20,
    '--w3m-font-family': '"Public Sans", sans-serif',
    '--w3m-border-radius-master': '9999px',
    '--w3m-accent': 'var(--primary-brand)',
  },
  themeMode: (localStorage.getItem('theme') as 'dark' | 'light') ?? 'dark',
});
