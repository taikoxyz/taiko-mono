import { injected, walletConnect } from '@wagmi/connectors';
import { createConfig, http, reconnect } from '@wagmi/core';
import { hardhat } from '@wagmi/core/chains';

import { PUBLIC_WALLETCONNECT_PROJECT_ID } from '$env/static/public';

const projectId = PUBLIC_WALLETCONNECT_PROJECT_ID;

import { chainIdToChain } from '$lib/chain/chains';

export const devnet = chainIdToChain(167001);
export const mainnet = chainIdToChain(167000);

const baseConfig = {
  chains: [hardhat, mainnet, devnet],
  projectId,
  metadata: {},
  batch: {
    multicall: false,
  },
  transports: {
    [hardhat.id]: http('http://localhost:8545'),
    [devnet.id]: http('https://rpc.internal.taiko.xyz'),
    [mainnet.id]: http('https://rpc.mainnet.taiko.xyz'),
  },
} as const;

export const config = createConfig({
  ...baseConfig,
  connectors: [walletConnect({ projectId, showQrModal: false }), injected()],
});

export const publicConfig = createConfig(baseConfig);

reconnect(config);
