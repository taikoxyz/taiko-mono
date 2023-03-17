import { writable } from 'svelte/store';

import type { RelayerAPI, RelayerBlockInfo } from '../domain/relayerApi';

const relayerApi = writable<RelayerAPI>();
const relayerBlockInfoMap = writable<Map<number, RelayerBlockInfo>>();

export { relayerApi, relayerBlockInfoMap };
