"use client";

import { useEffect } from "react";

import { startWatching, stopWatching } from "./watcher";

/**
 * useWatcher — React conversion of the original SvelteKit `+layout.svelte`
 * onMount/onDestroy wiring of the wagmi account watcher.
 *
 * The original app called `startWatching()` once on mount and `stopWatching()`
 * on destroy. Here that lifecycle is expressed as a single mount-only effect so
 * it can be invoked exactly once from the client Providers boundary
 * (AppClientInit). Behavior is preserved verbatim — `startWatching` remains
 * idempotent (guarded by its internal `isWatching` flag), and `stopWatching`
 * tears down the `watchAccount` subscription.
 *
 * Renders nothing; call it from a client component mounted once.
 */
export function useWatcher() {
  useEffect(() => {
    // startWatching is async; fire-and-forget exactly like the original onMount.
    void startWatching();

    return () => {
      stopWatching();
    };
  }, []);
}
