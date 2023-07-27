import type { GetAccountResult, PublicClient } from '@wagmi/core';
import { writable } from 'svelte/store';

export type Account = GetAccountResult<PublicClient>;

export const account = writable<Account>();
