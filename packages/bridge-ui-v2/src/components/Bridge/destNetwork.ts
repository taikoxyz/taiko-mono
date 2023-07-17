import type { Chain } from '@wagmi/core';
import { writable } from 'svelte/store';

export const destNetwork = writable<Chain>();
