import type { RelayerAPI } from "src/domain/relayerApi";
import { writable } from "svelte/store";

const relayerApi = writable<RelayerAPI>();

export { relayerApi };