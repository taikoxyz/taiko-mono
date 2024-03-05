import { injected, walletConnect } from '@wagmi/connectors';
import { createConfig, getPublicClient, http, reconnect } from '@wagmi/core';
import type { Chain } from 'viem';

import { PUBLIC_WALLETCONNECT_PROJECT_ID } from '$env/static/public';
import { chains } from '$libs/chain';

const projectId = PUBLIC_WALLETCONNECT_PROJECT_ID;

export const publicClient = async (chainId: number) => {
  return await getPublicClient(config, { chainId });
};

function createTransports(chains: readonly Chain[]) {
  const transports = chains.reduce(
    (acc, chain) => {
      const { id } = chain;
      return { ...acc, [id]: http() };
    },
    {} as Record<number, ReturnType<typeof http>>,
  );

  return transports;
}

export const config = createConfig({
  chains: [...chains],
  connectors: [walletConnect({ projectId, showQrModal: false }), injected()],
  transports: createTransports(chains),
});

reconnect(config);
