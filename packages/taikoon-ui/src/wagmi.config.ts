import { injected, walletConnect } from '@wagmi/connectors';
import { createConfig, http, reconnect } from '@wagmi/core';
import { hardhat } from '@wagmi/core/chains';

import { PUBLIC_ENV, PUBLIC_WALLETCONNECT_PROJECT_ID } from '$env/static/public';

const projectId = PUBLIC_WALLETCONNECT_PROJECT_ID;

import { type Chain } from 'viem';

import { chainIdToChain } from '$lib/chain/chains';

export const devnet = chainIdToChain(167001);
export const taiko = chainIdToChain(167000);

const devChains: [Chain, ...Chain[]] = [devnet, hardhat];
const prodChains: [Chain, ...Chain[]] = [taiko];

const baseConfig = {
  chains: PUBLIC_ENV === 'prod' ? prodChains : ([...devChains, ...prodChains] as [Chain, ...Chain[]]),
  defaultChain: taiko,
  projectId,
  metadata: {},
  batch: {
    multicall: false,
  },
  transports: {
    [hardhat.id]: http('http://localhost:8545'),
    [taiko.id]: http('https://rpc.mainnet.taiko.xyz'),
  },
} as const;

export const config = createConfig({
  ...baseConfig,
  connectors: [walletConnect({ projectId, showQrModal: false }), injected()],
});

export const publicConfig = createConfig(baseConfig);

reconnect(config);
