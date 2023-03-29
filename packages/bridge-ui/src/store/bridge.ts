import { derived, writable } from 'svelte/store';
import { BridgeType } from '../domain/bridge';
import { bridges } from '../bridge/bridges';

export const bridgeType = writable<BridgeType>(BridgeType.ETH);

export const activeBridge = derived(bridgeType, ($value) => bridges[$value]);
