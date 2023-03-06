import type { RelayerAPI, RelayerBlockInfo } from "../domain/relayerApi";
import { writable } from "svelte/store";

const relayerApi = writable<RelayerAPI>();
const relayerBlockInfoMap = writable<Map<number, RelayerBlockInfo>>();

export { relayerApi, relayerBlockInfoMap };