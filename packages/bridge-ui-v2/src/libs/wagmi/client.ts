import { configureChains, createConfig } from '@wagmi/core';
import { w3mConnectors, w3mProvider } from '@web3modal/ethereum';

import { PUBLIC_WALLETCONNECT_PROJECT_ID } from '$env/static/public';
import { chains } from '$libs/chain';

const projectId = PUBLIC_WALLETCONNECT_PROJECT_ID;

export const { publicClient } = configureChains(chains, [w3mProvider({ projectId })]);

export const wagmiConfig = createConfig({
  autoConnect: true,
  connectors: w3mConnectors({ projectId, chains }),
  publicClient,
});
