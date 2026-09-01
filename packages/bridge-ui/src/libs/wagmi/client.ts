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
      // Pass the resolved URL, never undefined: viem 2.9.31 keys its batch scheduler on the URL
      // *argument* and caches schedulers in a module-level map, so http(undefined, ...) would give
      // every chain the same scheduler and send one chain's reads to another chain's endpoint.
      const url = chain.rpcUrls.default.http[0];

      // A chain configured with an empty `http` array would hand `undefined` straight back into
      // that trap, and silently: reads would still resolve, just against another chain's endpoint.
      // Refusing to build the config is the loud failure that misrouting never gives you - one of
      // its symptoms is an uncloseable "bridge is paused" modal for every user, because
      // checkForPausedContracts reads `paused` per chain and treats an unreadable answer as paused.
      if (!url) throw new Error(`Chain ${id} has no RPC URL configured; batched transports need one per chain`);

      return { ...acc, [id]: http(url, { batch: RPC_BATCH_CONFIG }) };
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
