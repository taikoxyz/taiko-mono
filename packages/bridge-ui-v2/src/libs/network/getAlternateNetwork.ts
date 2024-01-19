import { get } from 'svelte/store';

import { chainConfig } from '$chainConfig';
import { network } from '$stores/network';

export const getAlternateNetwork = (): number | null => {
  const currentNetwork = get(network);
  if (currentNetwork === null || currentNetwork === undefined) {
    return null;
  }
  const chainKeys: number[] = Object.keys(chainConfig).map(Number);

  // only allow switching between two chains, if we have more we do not use this util
  if (chainKeys.length !== 2) {
    return null;
  }

  const alternateChainId = chainKeys.find((key) => key !== currentNetwork.id);

  if (!alternateChainId) return null;
  return alternateChainId;
};
