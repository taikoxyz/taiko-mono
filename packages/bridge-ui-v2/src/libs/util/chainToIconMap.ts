import type { ComponentType } from 'svelte';

import { EthIcon, TaikoIcon } from '$components/Icon';
import { PUBLIC_L1_CHAIN_ID, PUBLIC_L2_CHAIN_ID } from '$env/static/public';

export const chainToIconMap: Record<string, ComponentType> = {
  [PUBLIC_L1_CHAIN_ID]: EthIcon,
  [PUBLIC_L2_CHAIN_ID]: TaikoIcon,
  // TODO: L3
};
