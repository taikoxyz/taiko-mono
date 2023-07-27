import type { ComponentType } from 'svelte';

import { BllIcon, EthIcon, HorseIcon } from '$components/Icon';

export const symbolToIconMap: Record<string, ComponentType> = {
  ETH: EthIcon,
  BLL: BllIcon,
  HORSE: HorseIcon,
};
