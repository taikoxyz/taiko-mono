import { injected, walletConnect } from '@wagmi/connectors';
import { createConfig, http, reconnect } from '@wagmi/core';
import { hardhat, holesky, sepolia } from '@wagmi/core/chains';

import { PUBLIC_WALLETCONNECT_PROJECT_ID } from '$env/static/public';

const projectId = PUBLIC_WALLETCONNECT_PROJECT_ID;

import { chainIdToChain } from '$lib/chain/chains';

const devnet = chainIdToChain(167001);
const baseConfig = {
  chains: [hardhat, holesky, sepolia, devnet],
  projectId,
  metadata: {},
  batch: {
    multicall: false,
  },
  transports: {
    [hardhat.id]: http('http://localhost:8545'),
    [holesky.id]: http('https://ethereum-holesky.blockpi.network/v1/rpc/public'),
    [devnet.id]: http('https://rpc.internal.taiko.xyz'),
  },
} as const;

export const config = createConfig({
  ...baseConfig,
  connectors: [walletConnect({ projectId, showQrModal: false }), injected()],
});

export const publicConfig = createConfig(baseConfig);

reconnect(config);
