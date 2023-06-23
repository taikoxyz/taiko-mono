import { EthereumClient } from '@web3modal/ethereum';
import { Web3Modal } from '@web3modal/html';

import { PUBLIC_WEB3_MODAL_PROJECT_ID } from '$env/static/public';
import { chains, wagmiConfig } from '$libs/wagmi';

const projectId = PUBLIC_WEB3_MODAL_PROJECT_ID;

const ethereumClient = new EthereumClient(wagmiConfig, chains);

export const web3modal = new Web3Modal({ projectId }, ethereumClient);
