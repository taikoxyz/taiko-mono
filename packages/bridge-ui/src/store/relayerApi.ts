import type { PaginationInfo, RelayerBlockInfo } from '../domain/relayerApi';
import { writable } from 'svelte/store';

export const paginationInfo = writable<PaginationInfo>();

export const relayerBlockInfoMap = writable<Map<number, RelayerBlockInfo>>();
