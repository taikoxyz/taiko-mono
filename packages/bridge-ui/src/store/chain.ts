import { writable } from 'svelte/store';

import type { Chain } from '../domain/chain';

export const srcChain = writable<Chain>();

export const destChain = writable<Chain>();
