import { writable } from 'svelte/store';

import type { PaginationInfo, RelayerBlockInfo } from '$libs/relayer/relayerApi';

export const paginationInfo = writable<PaginationInfo>();

export const relayerBlockInfoMap = writable<Map<number, RelayerBlockInfo>>();
