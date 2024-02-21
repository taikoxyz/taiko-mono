import type { GetAccountReturnType } from '@wagmi/core';
import { writable } from 'svelte/store';

export type Account = GetAccountReturnType;

export const account = writable<GetAccountReturnType>();
