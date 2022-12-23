import { derived, writable } from "svelte/store";
import { BridgeType } from "../domain/bridge";
import type { Bridge } from "../domain/bridge";

export const bridgeType = writable<BridgeType>(BridgeType.ETH);

export const bridges = writable<Map<BridgeType, Bridge>>(
  new Map<BridgeType, Bridge>()
);

export const activeBridge = derived([bridgeType, bridges], ($values) =>
  $values[1].get($values[0])
);

export const chainIdToTokenVaultAddress = writable<Map<number, string>>(
  new Map<number, string>()
);
