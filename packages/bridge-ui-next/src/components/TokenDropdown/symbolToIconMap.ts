import type { ComponentType } from "react";

import { BllIcon, EthIcon, HorseIcon, TTKOIcon } from "@/components/Icon";

// Component-shaped icons (React function components). The original typed these as
// Svelte `ComponentType`; here they are React components accepting the same
// `{ size? }` prop the callers pass.
type IconComponent = ComponentType<{ size?: number }>;

export const baseSymbolToIconMap: Record<string, IconComponent> = {
  ETH: EthIcon,
  BLL: BllIcon,
  HORSE: HorseIcon,
};

/**
 * The TTKO symbol changes depending on the layer or testnet, we intercept it
 * As we will only match configured tokens we don't need to worry
 * about other tokens that might start with TTKO
 * TODO: Remove once we are on mainnet?
 */
export const symbolToIconMap = new Proxy(baseSymbolToIconMap, {
  get(target, prop: string) {
    if (prop.startsWith("TAIKO")) {
      return TTKOIcon;
    }
    return target[prop] || null;
  },
}) as Record<string, IconComponent | null>;
