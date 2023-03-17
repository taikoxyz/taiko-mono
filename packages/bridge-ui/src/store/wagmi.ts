import type { Client } from '@wagmi/core';
import { writable } from 'svelte/store';
export const wagmiClient = writable<Client>();
