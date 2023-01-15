import { writable } from "svelte/store";

import type { Transaction } from "ethers";
import type { BridgeTransaction, Transactioner } from "../domain/transactions";

const pendingTransactions = writable<Transaction[]>([]);
const transactions = writable<BridgeTransaction[]>([]);
const transactioner = writable<Transactioner>();
const showTransactionDetails = writable<BridgeTransaction>();
const showMessageStatusTooltip = writable<boolean>();
export { pendingTransactions, transactions, transactioner, showTransactionDetails, showMessageStatusTooltip };
