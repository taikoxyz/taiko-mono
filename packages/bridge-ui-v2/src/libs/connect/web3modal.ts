import { EthereumClient } from '@web3modal/ethereum';
import { Web3Modal } from '@web3modal/html';

import { PUBLIC_WALLETCONNECT_PROJECT_ID } from '$env/static/public';
import { chains } from '$libs/chain';
import { wagmiConfig } from '$libs/wagmi';

const projectId = PUBLIC_WALLETCONNECT_PROJECT_ID;

const ethereumClient = new EthereumClient(wagmiConfig, chains);

export const web3modal = new Web3Modal(
  {
    projectId,
    // TODO: can we bring these vars into Tailwind theme?
    themeVariables: {
      '--w3m-font-family': 'Public Sans, sans-serif',
      '--w3m-accent-color': 'var(--primary-interactive)',
      '--w3m-accent-fill-color': 'var(--primary-content)',
      '--w3m-button-border-radius': '9999px',

      // '--w3m-background-border-radius': '1.25rem',
      // '--w3m-container-border-radius': '0rem',
      
      '--w3m-background-color': 'var(--neutral-background)',

      // TODO: customize the rest of the theme variables

      // Unofficial variables
      // @ts-ignore
      '--w3m-color-fg-1': 'var(--primary-content)',
      // '--w3m-color-fg-2': '',
      // '--w3m-color-fg-3': '',
      // '--w3m-color-bg-1': '',
      // '--w3m-color-bg-2': '',
      // '--w3m-color-bg-3': '',
      
    },
    themeMode: localStorage.getItem('theme') as 'dark' | 'light' ?? 'dark',
  },
  ethereumClient,
);
