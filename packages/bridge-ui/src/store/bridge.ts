import { derived, writable } from 'svelte/store';

import { bridges } from '../bridge/bridges';
import { BridgeType } from '../domain/bridge';

export const bridgeType = writable<BridgeType>(BridgeType.ETH);
export const activeBridge = derived(bridgeType, ($value) => bridges[$value]);
