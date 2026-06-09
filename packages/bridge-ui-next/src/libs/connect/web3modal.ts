"use client";

import { createWeb3Modal } from "@web3modal/wagmi/react";

import { publicEnv } from "@/config/env";
// TODO: once `$libs/chain` is ported, wire chainImages: `import { getChainImages } from '@/libs/chain';`
import { config } from "@/libs/wagmi";

/**
 * Web3Modal — ported from libs/connect/web3modal.ts.
 *
 * Original (SvelteKit SPA, ssr=false) instantiated `web3modal = createWeb3Modal(...)`
 * at module top-level and exported the instance; three components consume it
 * imperatively (`web3modal.open()`, `web3modal.setThemeMode()`,
 * `web3modal.subscribeState()`).
 *
 * The original module reads `localStorage` (themeMode) and calls `getChainImages()`
 * at module load, which crashes under SSR/RSC. To preserve the SPA contract without
 * an SSR crash, instantiation is deferred to `initWeb3Modal()` (called once from the
 * client Providers/AppClientInit boundary inside useEffect), and the resulting
 * singleton is exposed via `getWeb3Modal()` / the `web3modal` proxy. Idempotent.
 */
type Web3Modal = ReturnType<typeof createWeb3Modal>;

let web3modalInstance: Web3Modal | undefined;

export function initWeb3Modal(): Web3Modal | undefined {
  if (web3modalInstance || typeof window === "undefined")
    return web3modalInstance;

  const projectId = publicEnv.WALLETCONNECT_PROJECT_ID;
  // TODO: wire chainImages once `$libs/chain` is ported -> `const chainImages = getChainImages();`

  web3modalInstance = createWeb3Modal({
    wagmiConfig: config,
    projectId,
    featuredWalletIds: [],
    allowUnsupportedChain: true,
    excludeWalletIds: [],
    // chains,
    // chainImages,
    themeVariables: {
      "--w3m-color-mix": "var(--neutral-background)",
      "--w3m-color-mix-strength": 20,
      "--w3m-font-family": '"Public Sans", sans-serif',
      "--w3m-border-radius-master": "9999px",
      "--w3m-accent": "var(--primary-brand)",
    },
    themeMode:
      (window.localStorage.getItem("theme") as "dark" | "light") ?? "dark",
  });

  return web3modalInstance;
}

/**
 * Returns the initialized Web3Modal singleton. Lazily initializes on first call so
 * imperative client-side callers (post-mount) get a live instance even if
 * `initWeb3Modal()` has not run yet. Returns `undefined` only when called on the
 * server (no `window`).
 */
export function getWeb3Modal(): Web3Modal | undefined {
  return web3modalInstance ?? initWeb3Modal();
}

/**
 * Imperative-API parity with the original `export const web3modal`. A Proxy
 * transparently forwards member access (`.open()`, `.setThemeMode()`,
 * `.subscribeState()`, ...) to the lazily-initialized singleton, so existing
 * callers `import { web3modal } from '$libs/connect'` keep working unchanged.
 *
 * Access is client-only (callers invoke it post-mount); on the server the target
 * is undefined and member access throws, matching the original module's
 * browser-only assumption.
 */
export const web3modal = new Proxy({} as Web3Modal, {
  get(_target, prop, receiver) {
    const instance = getWeb3Modal();
    if (!instance) {
      throw new Error(
        "web3modal accessed before initialization (browser-only)",
      );
    }
    const value = Reflect.get(instance as object, prop, receiver);
    return typeof value === "function" ? value.bind(instance) : value;
  },
});
