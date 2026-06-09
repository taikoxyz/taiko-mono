"use client";

import { injected, walletConnect } from "@wagmi/connectors";
import { createConfig, getPublicClient, http, reconnect } from "@wagmi/core";
import type { Chain } from "viem";
import { mainnet } from "viem/chains";

import { chains } from "@/libs/chain";
import { publicEnv } from "@/config/env";

/**
 * Centralized wagmi config — ported from libs/wagmi/client.ts.
 *
 * SvelteKit `$env/static/public` PUBLIC_WALLETCONNECT_PROJECT_ID ->
 * NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID (via publicEnv).
 *
 * `chains` is derived from the generated `$chainConfig` through `@/libs/chain`,
 * exactly as the original. The original SvelteKit app is an SPA (ssr=false), so
 * this module is only ever instantiated inside the client Providers boundary.
 */
const projectId = publicEnv.WALLETCONNECT_PROJECT_ID;

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

// `chains` is derived from the generated `$chainConfig`. In a correctly
// configured deployment it is always non-empty. During a build/prerender with
// placeholder config (e.g. SKIP_ENV_VALIDATION) it can be empty, and wagmi's
// `createConfig` requires at least one chain — fall back to mainnet so the
// static build does not crash. At runtime with real config this branch is
// never taken, so happy-path behaviour is unchanged.
const activeChains = (chains.length > 0 ? chains : [mainnet]) as [
  Chain,
  ...Chain[],
];

export const config = createConfig({
  chains: activeChains,
  connectors: [walletConnect({ projectId, showQrModal: false }), injected()],
  transports: createTransports(activeChains),
});

// Export the reconnection promise so watcher can wait for it
export const reconnectionPromise = reconnect(config);

declare module "wagmi" {
  interface Register {
    config: typeof config;
  }
}
