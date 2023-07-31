import { writable } from 'svelte/store';

// TODO: move this to local state

export const contractTypeStore = writable(''); // TODO: TokenType
export const tokenIdStore = writable<Array<number>>([]);
export const errorIdStore = writable<Array<number>>([]);
