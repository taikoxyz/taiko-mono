import { injected, walletConnect } from '@wagmi/connectors';
import { createConfig, getPublicClient, http, reconnect } from '@wagmi/core';
import type { Chain } from 'viem';

import { PUBLIC_WALLETCONNECT_PROJECT_ID } from '$env/static/public';
import { chains } from '$libs/chain';

const projectId = PUBLIC_WALLETCONNECT_PROJECT_ID;

export const publicClient = async (chainId: number) => {
  return await getPublicClient(config, { chainId });
};

// Every transaction row on /transactions costs two RPC reads, and they all fire at once: a
// 300-transaction history was 600 separate HTTP requests, enough to trip the RPC gateway's rate
// limiter, which answers 429 with an HTML body that viem cannot parse. Batching collapses them
// into a handful of requests. This assumes every configured RPC accepts JSON-RPC batch requests.
export const RPC_BATCH_CONFIG = { batchSize: 50, wait: 20 } as const;

export function createTransports(chains: readonly Chain[]) {
  const transports = chains.reduce(
    (acc, chain) => {
      const { id } = chain;
      return { ...acc, [id]: http(undefined, { batch: RPC_BATCH_CONFIG }) };
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

// Export the reconnection promise so watcher can wait for it
export const reconnectionPromise = reconnect(config);
