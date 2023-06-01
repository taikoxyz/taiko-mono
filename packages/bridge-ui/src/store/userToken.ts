import { writable } from 'svelte/store';

import type { Token } from '../domain/token';

export const userTokens = writable<Token[]>([]);
