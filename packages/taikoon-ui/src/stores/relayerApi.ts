import { writable } from 'svelte/store';

import type { PaginationInfo, RelayerBlockInfo } from '../../lib/relayer/types';

export const paginationInfo = writable<PaginationInfo>();

export const relayerBlockInfoMap = writable<Map<number, RelayerBlockInfo>>();
