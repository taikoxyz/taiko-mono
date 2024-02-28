import { writable } from 'svelte/store';

import type { BridgeTransaction } from '$libs/bridge';

export const transactionStore = writable<BridgeTransaction[]>([]);
