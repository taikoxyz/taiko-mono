import { writable } from 'svelte/store';

import type { Transaction } from 'ethers';
import type { BridgeTransaction } from '../domain/transaction';

export const pendingTransactions = writable<Transaction[]>([]);

export const transactions = writable<BridgeTransaction[]>([]);
