import { writable } from 'svelte/store';

export const isMobileStore = writable(window.innerWidth < 768);
