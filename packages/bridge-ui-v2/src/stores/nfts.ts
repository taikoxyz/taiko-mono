import { writable } from 'svelte/store';

export const contractTypeStore = writable('');
export const tokenIdStore = writable<Array<number>>([]);
export const errorIdStore = writable<Array<number>>([]);
