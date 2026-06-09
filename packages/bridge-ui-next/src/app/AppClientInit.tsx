"use client";

import { useEffect } from "react";

import { initWeb3Modal } from "@/libs/connect/web3modal";
import { initializeMediaQueries } from "@/libs/util/responsiveCheck";
import { useWatcher } from "@/libs/wagmi";

/**
 * AppClientInit — ports the original +layout.svelte onMount/onDestroy side effects.
 *
 * Wired here (ports the original +layout.svelte onMount/onDestroy):
 *  - startWatching/stopWatching (libs/wagmi/watcher.ts) via useWatcher() — opens
 *    switchChainModal on unsupported chains; runs checkForPausedContracts ->
 *    bridgePausedModal.
 *  - Web3Modal init (client-only; reads localStorage).
 *  - initializeMediaQueries (libs/util/responsiveCheck.ts).
 *  - Desktop-only pointermove syncing of the --x/--y/--xp/--yp CSS vars on
 *    <html>, which feed the [data-glow-border] glow effect.
 *
 * Renders nothing.
 */
export default function AppClientInit() {
  // wagmi account watcher (ports the original +layout.svelte onMount/onDestroy
  // startWatching/stopWatching). Mount-only; idempotent. Also triggers
  // checkForPausedContracts -> bridgePausedModal inside startWatching.
  useWatcher();

  useEffect(() => {
    initWeb3Modal();

    // ---- Media queries (ports the original +layout.svelte initializeMediaQueries) ----
    // Idempotent: sets the desktop/tablet/mobile breakpoint stores and attaches its
    // own `change` listeners internally. Drives the responsive hooks app-wide.
    initializeMediaQueries();

    // ---- Pointer variables for the glow-border effect (desktop only) ----
    const desktopQuery = window.matchMedia("(min-width: 768px)");

    const syncPointer = (event: PointerEvent) => {
      const { clientX: x, clientY: y } = event;
      const root = document.documentElement;
      root.style.setProperty("--x", x.toFixed(2));
      root.style.setProperty("--xp", (x / window.innerWidth).toFixed(2));
      root.style.setProperty("--y", y.toFixed(2));
      root.style.setProperty("--yp", (y / window.innerHeight).toFixed(2));
    };

    let listening = false;
    const attach = () => {
      if (!listening && desktopQuery.matches) {
        document.body.addEventListener("pointermove", syncPointer);
        listening = true;
      } else if (listening && !desktopQuery.matches) {
        document.body.removeEventListener("pointermove", syncPointer);
        listening = false;
      }
    };

    attach();
    desktopQuery.addEventListener("change", attach);

    return () => {
      desktopQuery.removeEventListener("change", attach);
      if (listening) {
        document.body.removeEventListener("pointermove", syncPointer);
      }
    };
  }, []);

  return null;
}
