import { writable } from "svelte/store";

import type { Transaction } from "ethers";

const pendingTransactions = writable<Transaction[]>([]);

export { pendingTransactions };
