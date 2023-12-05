import { writable } from 'svelte/store';

export const enum Theme {
  DARK = 'dark',
  LIGHT = 'light',
}

export const theme = writable<Theme>((localStorage.getItem('theme') as Theme) || Theme.DARK);
