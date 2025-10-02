import { writable } from 'svelte/store';

export const enum Theme {
  DARK = 'dark',
  LIGHT = 'light',
}

export const theme = writable<Theme>(Theme.DARK);

// Avoid accessing localStorage during SSR. Guard with a runtime window check.
const isBrowser = typeof window !== 'undefined';
if (isBrowser) {
  const saved = localStorage.getItem('theme') as Theme | null;
  if (saved === Theme.DARK || saved === Theme.LIGHT) {
    theme.set(saved);
  }
}
