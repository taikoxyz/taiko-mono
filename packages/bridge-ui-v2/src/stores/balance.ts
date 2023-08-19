import { writable } from 'svelte/store';

export const ethBalance = writable<FetchBalanceResult>();
