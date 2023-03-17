import { derived, writable } from 'svelte/store';
import { BridgeType } from '../domain/bridge';
import { bridgesMap } from '../bridge/bridges';

export const bridgeType = writable<BridgeType>(BridgeType.ETH);

export const activeBridge = derived(bridgeType, ($value) =>
  bridgesMap.get($value),
);

export const chainIdToTokenVaultAddress = writable<Map<number, string>>(
  new Map<number, string>(),
);
