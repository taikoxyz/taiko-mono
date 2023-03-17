import { derived, writable } from 'svelte/store';
import { BridgeType } from '../domain/bridge';
import { bridgesMap } from '../bridge/birdges';

export const bridgeType = writable<BridgeType>(BridgeType.ETH);

export const activeBridge = derived([bridgeType], ($values) =>
  bridgesMap.get($values[0]),
);

export const chainIdToTokenVaultAddress = writable<Map<number, string>>(
  new Map<number, string>(),
);
