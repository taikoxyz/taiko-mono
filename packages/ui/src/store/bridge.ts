import type { Bridge } from "../domain/bridge";
import { BridgeType } from "../domain/bridge";
import { derived, writable } from "svelte/store";

export const bridges = writable<Map<BridgeType, Bridge>>(
  new Map<BridgeType, Bridge>()
);
export const bridgeType = writable<BridgeType>(BridgeType.ETH);

export const activeBridge = derived([bridgeType, bridges], ($values) =>
  $values[1].get($values[0])
);
