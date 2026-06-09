"use client";

// Ported from components/Bridge/Bridge.svelte.
//
// Top-level switch between the fungible (ERC20/ETH) bridge and the NFT bridge,
// driven by the `activeBridge` vanilla store. Mirrors the original:
//   {#if $activeBridge === BridgeTypes.FUNGIBLE} <FungibleBridge /> {:else} <NftBridge /> {/if}

import FungibleBridge from "./FungibleBridge";
import NftBridge from "./NFTBridge";
import { activeBridge, useBridgeState } from "./state";
import { BridgeTypes } from "./types";

export default function Bridge() {
  const active = useBridgeState(activeBridge);

  return active === BridgeTypes.FUNGIBLE ? <FungibleBridge /> : <NftBridge />;
}
