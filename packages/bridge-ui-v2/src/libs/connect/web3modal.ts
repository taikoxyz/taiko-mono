import { EthereumClient } from '@web3modal/ethereum';
import { Web3Modal } from '@web3modal/html';

import { PUBLIC_WALLETCONNECT_PROJECT_ID } from '$env/static/public';
import { chains, getChainImages } from '$libs/chain';
import { wagmiConfig } from '$libs/wagmi';

const projectId = PUBLIC_WALLETCONNECT_PROJECT_ID;

const ethereumClient = new EthereumClient(wagmiConfig, chains);

const chainImages = getChainImages();

export const web3modal = new Web3Modal(
  {
    projectId,
    chainImages,
    // TODO: can we bring these vars into Tailwind theme?
    themeVariables: {
      '--w3m-font-family': '"Public Sans", sans-serif',
      '--w3m-font-feature-settings': 'normal',
      '--w3m-button-border-radius': '9999px',

      // Body small regular
      '--w3m-text-small-regular-size': '14px',
      '--w3m-text-small-regular-weight': '400',
      '--w3m-text-small-regular-line-height': '20px',

      // Body regular
      '--w3m-text-medium-regular-size': '16px',
      '--w3m-text-medium-regular-weight': '400',
      '--w3m-text-medium-regular-line-height': '24px',
      '--w3m-text-medium-regular-letter-spacing': 'normal',

      // Title body bold
      '--w3m-text-big-bold-size': '18px',
      '--w3m-text-big-bold-weight': '700',
      '--w3m-text-big-bold-line-height': '24px',

      '--w3m-background-color': 'var(--primary-brand)',
      '--w3m-overlay-background-color': 'var(--overlay-background)',
      '--w3m-background-border-radius': '20px',
      '--w3m-container-border-radius': '0',

      // Unofficial variables
      // @ts-ignore
      '--w3m-color-fg-1': 'var(--primary-content)',
      '--w3m-color-bg-1': 'var(--primary-background)',
      '--w3m-color-bg-2': 'var(--neutral-background)',
      '--w3m-color-overlay': 'none',
      '--w3m-accent-color': 'var(--neutral-background)',
      '--w3m-accent-fill-color': 'var(--dark-background)',
    },
    themeMode: (localStorage.getItem('theme') as 'dark' | 'light') ?? 'dark',
  },
  ethereumClient,
);
