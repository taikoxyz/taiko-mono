import { configureChains } from '@wagmi/core';
import { publicProvider } from '@wagmi/core/providers/public';
import { walletConnectProvider } from '@web3modal/wagmi';
import { defaultWagmiConfig } from '@web3modal/wagmi/react';

import { PUBLIC_WALLETCONNECT_PROJECT_ID } from '$env/static/public';
import { chains as chainsFromEnv } from '$libs/chain';

const projectId = PUBLIC_WALLETCONNECT_PROJECT_ID;

export const { chains, publicClient } = configureChains(chainsFromEnv, [
  walletConnectProvider({ projectId }),
  publicProvider(),
]);

export const wagmiConfig = defaultWagmiConfig({ chains, projectId });
