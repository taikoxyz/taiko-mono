import type { FetchBalanceResult } from '@wagmi/core';
import { writable } from 'svelte/store';

export const ethBalance = writable<Maybe<FetchBalanceResult>>(null);
