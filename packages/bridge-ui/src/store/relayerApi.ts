import type { RelayerBlockInfo } from '../domain/relayerApi';
import { writable } from 'svelte/store';

export const relayerBlockInfoMap = writable<Map<number, RelayerBlockInfo>>();
