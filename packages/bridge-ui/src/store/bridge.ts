import { derived, writable } from 'svelte/store';
import { BridgeChainType, BridgeType } from '../domain/bridge';
import { bridges } from '../bridge/bridges';

export const bridgeType = writable<BridgeType>(BridgeType.ETH);

export const bridgeChainType = writable<BridgeChainType>(BridgeChainType.L1_L2);

export const activeBridge = derived(bridgeType, (value) => bridges[value]);
