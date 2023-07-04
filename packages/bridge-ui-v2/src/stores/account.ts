import { writable } from 'svelte/store';
import type { PublicClient } from 'wagmi';
import type { GetAccountResult } from 'wagmi/actions';

export const account = writable<GetAccountResult<PublicClient>>();
