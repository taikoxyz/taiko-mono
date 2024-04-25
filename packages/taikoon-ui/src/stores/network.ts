import { writable } from 'svelte/store';
import type { Chain } from 'viem';

export const connectedSourceChain = writable<Chain>();

export const switchingNetwork = writable<boolean>(false);
