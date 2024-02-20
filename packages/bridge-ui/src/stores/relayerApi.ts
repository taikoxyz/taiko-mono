import { writable } from 'svelte/store';

import type { PaginationInfo, RelayerBlockInfo } from '$libs/relayer/types';

export const paginationInfo = writable<PaginationInfo>();

export const relayerBlockInfoMap = writable<Map<number, RelayerBlockInfo>>();
