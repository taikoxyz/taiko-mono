"use client";

// Ported from components/Bridge/BridgeTabs.svelte.
//
// Token / NFT bridge-type toggle. Only rendered when the NFT bridge feature flag
// is enabled (PUBLIC_NFT_BRIDGE_ENABLED === 'true' -> publicEnv.NFT_BRIDGE_ENABLED).
// Pixel parity: button class strings and DOM structure copied verbatim.

import type { MouseEventHandler } from "react";

import { useTranslation } from "@/i18n/useTranslation";
import { publicEnv } from "@/config/env";
import { classNames } from "@/libs/util/classNames";

import { activeBridge, useBridgeState } from "./state";
import { BridgeTypes } from "./types";

export interface BridgeTabsProps {
  /** Pass-through className (Svelte `$$props.class`). */
  className?: string;
  /** Forwarded root click handler (mirrors Svelte's `on:click` DOM event forwarding). */
  onClick?: MouseEventHandler<HTMLDivElement>;
}

export default function BridgeTabs({ className, onClick }: BridgeTabsProps) {
  const { t } = useTranslation();

  const active = useBridgeState(activeBridge);

  // Original: `let classes = classNames('space-x-2', $$props.class);` (computed once).
  const classes = classNames("space-x-2", className);

  const isERC20Bridge = active === BridgeTypes.FUNGIBLE;
  const isNFTBridge = active === BridgeTypes.NFT;

  const onBridgeClick = (type: BridgeTypes) => {
    activeBridge.setState(type, true);
  };

  if (publicEnv.NFT_BRIDGE_ENABLED !== "true") return null;

  return (
    <div className={classes} onClick={onClick}>
      <button
        className={`${isERC20Bridge ? "btn-primary text-white" : "btn-ghost"} btn h-[40px] px-[28px] rounded-full`}
        onClick={() => onBridgeClick(BridgeTypes.FUNGIBLE)}
      >
        <span> {t("nav.token")}</span>
      </button>

      <button
        className={`${isNFTBridge ? "btn-primary text-white" : "btn-ghost"}  btn h-[40px] px-[28px] rounded-full`}
        onClick={() => onBridgeClick(BridgeTypes.NFT)}
      >
        <span> {t("nav.nft")}</span>
      </button>
    </div>
  );
}
