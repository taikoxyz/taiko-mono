import { writable } from 'svelte/store';

export const page = writable<import('@sveltejs/kit').Page>();
