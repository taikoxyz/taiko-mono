import { get } from 'svelte/store';

import { chainConfig } from '$chainConfig';
import { getValidBridges } from '$libs/bridge/bridges';
import { connectedSourceChain } from '$stores/network';

export const getAlternateNetwork = (): number | null => {
  const currentNetwork = get(connectedSourceChain);
  if (currentNetwork === null || currentNetwork === undefined) {
    return null;
  }
  const chainKeys: number[] = Object.keys(chainConfig).map(Number);

  let destination: number | null = null;
  // only allow switching between two chains, if we have more we find a valid destination chain
  if (chainKeys.length === 2) {
    destination = chainKeys.find((key) => key !== currentNetwork.id) || null;
    if (destination === null || destination === undefined) return null;
  } else {
    destination = findValidDestinationChain();
  }

  return destination;
};

const findValidDestinationChain = () => {
  const currentNetwork = get(connectedSourceChain);
  if (currentNetwork === null || currentNetwork === undefined) {
    return null;
  }

  const configuredBridges = getValidBridges(currentNetwork.id);
  if (configuredBridges && configuredBridges.length > 0) {
    return configuredBridges[0];
  }
  return null;
};
