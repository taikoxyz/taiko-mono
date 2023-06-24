import { EthereumClient } from '@web3modal/ethereum';
import { Web3Modal } from '@web3modal/html';

import { PUBLIC_WEB3_MODAL_PROJECT_ID } from '$env/static/public';
import { chains, wagmiConfig } from '$libs/wagmi';

const projectId = PUBLIC_WEB3_MODAL_PROJECT_ID;

const ethereumClient = new EthereumClient(wagmiConfig, chains);

export const web3modal = new Web3Modal(
  {
    projectId,
    // TODO: can we bring these vars into Tailwind theme?
    themeVariables: {
      '--w3m-background-border-radius': '1.25rem',
      '--w3m-container-border-radius': '0rem',
      '--w3m-font-family': 'Public Sans, system-ui, sans-serif',
      '--w3m-button-border-radius': '9999px',
      '--w3m-accent-color': 'var(--primary-interactive)',
      '--w3m-accent-fill-color': 'var(--primary-content)',
      '--w3m-background-color': 'var(--neutral-background)',
      // '--w3m-color-bg-1': 'var(--primary-background)',
      // TODO: customize the rest of the theme variables
    },
  },
  ethereumClient,
);
