import { derived, writable } from 'svelte/store';
import { BridgeType } from '../domain/bridge';
import { bridgesMap } from '../bridges/map';

export const bridgeType = writable<BridgeType>(BridgeType.ETH);

export const activeBridge = derived(bridgeType, ($bridgeType) =>
  bridgesMap.get($bridgeType),
);

export const chainIdToTokenVaultAddress = writable<Map<number, string>>(
  new Map<number, string>(),
);
