import type { ComponentType } from 'svelte';

import { BllIcon, EthIcon, HorseIcon, TTKOIcon } from '$components/Icon';

export const baseSymbolToIconMap: Record<string, ComponentType> = {
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
    if (prop.startsWith('TTKO')) {
      return TTKOIcon;
    }
    return target[prop] || null;
  },
});
