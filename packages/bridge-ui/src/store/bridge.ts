import { derived, writable } from 'svelte/store';
import { BridgeType, bridges } from '../domain/bridge';

export const bridgeType = writable<BridgeType>(BridgeType.ETH);

export const activeBridge = derived(bridgeType, ($bridgeType) =>
  bridges.get($bridgeType),
);

export const chainIdToTokenVaultAddress = writable<Map<number, string>>(
  new Map<number, string>(),
);
