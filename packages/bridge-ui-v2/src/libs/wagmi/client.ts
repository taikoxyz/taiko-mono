import { configureChains } from '@wagmi/core';
import { publicProvider } from '@wagmi/core/providers/public';
import { defaultWagmiConfig, walletConnectProvider } from '@web3modal/wagmi';

import { PUBLIC_WALLETCONNECT_PROJECT_ID } from '$env/static/public';
import { chains } from '$libs/chain';

const projectId = PUBLIC_WALLETCONNECT_PROJECT_ID;

export const { publicClient } = configureChains(chains, [walletConnectProvider({ projectId }), publicProvider()]);

export const wagmiConfig = defaultWagmiConfig({ chains, projectId });
