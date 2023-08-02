import { writable } from 'svelte/store';

export const isMobile = writable(window.innerWidth < 768);
