import { injected, walletConnect } from '@wagmi/connectors';
import { createConfig, http, reconnect } from '@wagmi/core';
import { taiko, taikoHekla } from 'viem/chains';

import { PUBLIC_WALLETCONNECT_PROJECT_ID } from '$env/static/public';
import { isDevelopmentEnv } from '$lib/util/isDevelopmentEnv';

const projectId = PUBLIC_WALLETCONNECT_PROJECT_ID;

const baseConfig = {
  chains: [isDevelopmentEnv ? taikoHekla : taiko],
  projectId,
  metadata: {},
  batch: {
    multicall: true,
  },
  transports: {
    [taikoHekla.id]: http('https://rpc.hekla.taiko.xyz'),
    [taiko.id]: http('https://rpc.mainnet.taiko.xyz'),
  },
} as const;

export const config = createConfig({
  ...baseConfig,
  connectors: [walletConnect({ projectId, showQrModal: false }), injected()],
});

export const publicConfig = createConfig(baseConfig);

reconnect(config);
