"use client";

// Ported from components/OnNetwork/OnNetwork.svelte.
//
// Renderless leaf primitive: subscribes to the connected source chain and invokes
// the `change` callback whenever the chain id actually changes. Mirrors the svelte
// store subscription where `prevNetwork` is seeded with the current value so the
// initial (immediate) emission does NOT fire `change` — only genuine transitions do.

import { useEffect, useRef } from "react";
import type { Chain } from "viem";

import { useConnectedSourceChain } from "@/stores/network";
import { noop } from "@/libs/util/noop";

export interface OnNetworkProps {
  /** Svelte `change` prop -> callback. Called as `change(newNetwork, oldNetwork)`. */
  change?: (
    newNetwork: Chain | undefined,
    oldNetwork: Chain | undefined,
  ) => void;
}

export default function OnNetwork({ change = noop }: OnNetworkProps) {
  const connectedSourceChain = useConnectedSourceChain();

  // Seed prevNetwork with the current value (mirrors `let prevNetwork = $connectedSourceChain`)
  // so the first render does not spuriously fire `change`.
  const prevNetworkRef = useRef<Chain | undefined>(connectedSourceChain);

  // Keep the latest `change` callback in a ref so the network effect does not
  // re-run (and re-fire) when an inline callback identity changes between renders.
  const changeRef = useRef(change);
  changeRef.current = change;

  useEffect(() => {
    const prevNetwork = prevNetworkRef.current;
    // only update if the network has actually changed
    if (connectedSourceChain?.id === prevNetwork?.id) return;
    changeRef.current(connectedSourceChain, prevNetwork);
    prevNetworkRef.current = connectedSourceChain;
  }, [connectedSourceChain]);

  return null;
}
